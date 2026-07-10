
//--------------------------------------------------------------------------------------------------------
// Module  : sd_file_reader
// Type    : synthesizable, IP's top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: A SD-card host to initialize SD-card and read files
//           Specify a filename, sd_file_reader will read out file content
//           Support CardType   : SDv1.1 , SDv2  or SDHCv2
//           Support FileSystem : FAT16 or FAT32
//--------------------------------------------------------------------------------------------------------
// Vendored from https://github.com/WangXuan95/FPGA-SDcard-Reader (GPL-3.0,
// see LICENSE.WangXuan95 in this directory).
//
// MODIFIED for the ND-120 project, 10-JUL-2026 (Ronny Hansen):
//   1. Added two status outputs: "scan_done" (the internal filesystem FSM
//      reached its DONE state - i.e. the file has been fully streamed out,
//      or the search/mount failed) and "found_file_size" (byte size of the
//      found file, valid once file_found=1).
//   2. Removed the SIMULATE-mode "$finish" generate block: this IP is
//      simulated INSIDE a larger testbench that must keep running (UART
//      dump verification) after the file read completes.
//   3. The target file name is now a runtime INPUT PORT (target_name /
//      target_len) instead of the FILE_NAME/FILE_NAME_LEN parameters (the
//      parameters remain but are unused). target_name is byte-0-in-low-byte
//      ordered (target_name[8*k +: 8] = k-th character); case-insensitive
//      as before. target_len = 0 never matches any file: that is the
//      "directory scan only" mode used for the LIST menu command.
//   4. Added directory-entry outputs (dir_entry_valid / dir_entry_name /
//      dir_entry_len / dir_entry_size / dir_entry_date / dir_entry_is_dir):
//      every plain file AND subdirectory entry the root search walks past
//      is reported with its parsed name (byte 0 in the low byte), byte
//      size, raw FAT date word and a directory flag, so a menu can list
//      the card contents. Subdirectory entries (attribute 0x10) are now
//      accepted by the entry parser; the file-search comparator skips them.
//   5. Added found_file_first_sector: absolute sector number of the found
//      file's first data sector (valid with file_found; used by the SD
//      writer for in-place rewrites of contiguous files).
//   6. sdcmd inout split into sdcmd_i/sdcmd_o/sdcmd_oe (see sdcmd_ctrl.v).
//--------------------------------------------------------------------------------------------------------

module sd_file_reader #(
    parameter            FILE_NAME_LEN = 11           , // length of FILE_NAME (in bytes). Since the length of "example.txt" is 11, so here is 11.
    parameter [52*8-1:0] FILE_NAME     = "example.txt", // file name to read, ignore upper and lower case
                                                        // For example, if you want to read a file named "HeLLo123.txt", this parameter can be "hello123.TXT", "HELLO123.txt" or "HEllo123.Txt"
    parameter      [2:0] CLK_DIV       = 3'd2,          // when clk =   0~ 25MHz , set CLK_DIV = 3'd1,
                                                        // when clk =  25~ 50MHz , set CLK_DIV = 3'd2,
                                                        // when clk =  50~100MHz , set CLK_DIV = 3'd3,
                                                        // when clk = 100~200MHz , set CLK_DIV = 3'd4,
                                                        // ......
    parameter            SIMULATE      = 0              // 0:normal use.         1:only for simulation
) (
    // rstn active-low, 1:working, 0:reset
    input  wire       rstn,
    // clock
    input  wire       clk,
    // SDcard signals (tristate resolved at the top level)
    output wire       sdclk,
    input  wire       sdcmd_i,
    output wire       sdcmd_o,
    output wire       sdcmd_oe,
    input  wire       sddat0,            // this module only reads DAT0
    // status output (optional for user)
    output wire [3:0] card_stat,         // show the sdcard initialize status
    output wire [1:0] card_type,         // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
    output wire [1:0] filesystem_type,   // 0=UNASSIGNED , 1=UNKNOWN , 2=FAT16 , 3=FAT32 
    output reg        file_found,        // 0=file not found, 1=file found
    // file content data output (sync with clk)
    output reg        outen,             // when outen=1, a byte of file content is read out from outbyte
    output reg  [7:0] outbyte,           // a byte of file content
    // --- ND-120 project modification (10-JUL-2026), see header ----------
    output wire       scan_done,         // filesystem FSM reached DONE (file fully read, or failed)
    output wire[31:0] found_file_size,   // size in bytes of the found file (valid once file_found=1)
    // (mod 3) runtime target file name; byte 0 in the low byte, case-insensitive.
    // target_len = 0 never matches: "directory scan only" mode.
    input  wire[52*8-1:0] target_name,
    input  wire[ 7:0]     target_len,
    // (mod 4) every file/subdirectory root entry walked during the search
    output wire           dir_entry_valid,  // 1-cycle pulse
    output wire[52*8-1:0] dir_entry_name,   // parsed name, byte 0 in the low byte
    output wire[ 7:0]     dir_entry_len,    // name length in bytes
    output wire[31:0]     dir_entry_size,   // byte size (0 for directories)
    output wire[15:0]     dir_entry_date,   // raw FAT date word (offset 0x18)
    output wire           dir_entry_is_dir, // 1 = subdirectory entry
    // (mod 5) absolute first data sector of the found file (with file_found)
    output wire[31:0]     found_file_first_sector
);



function  [7:0] toUpperCase;
    input [7:0] in;
begin
    toUpperCase = (in>=8'h61 && in<=8'h7A) ? (in & 8'b11011111) : in;
end
endfunction



wire [52*8-1:0] FILE_NAME_UPPER;

generate genvar k;
    for (k=0; k<52; k=k+1) begin : convert_fname_to_upper
        assign FILE_NAME_UPPER[k*8 +: 8] = toUpperCase( FILE_NAME[k*8 +: 8] );
    end
endgenerate



initial file_found = 1'b0;
initial {outen,outbyte} = 0;


reg         read_start     = 1'b0;
reg  [31:0] read_sector_no = 0;
wire        read_done;

wire        rvalid;
wire [ 8:0] raddr;
wire [ 7:0] rdata;

reg  [31:0] rootdir_sector = 0 , rootdir_sector_t;             // rootdir sector number (FAT16 only)
reg  [15:0] rootdir_sectorcount = 0 , rootdir_sectorcount_t;   // (FAT16 only)

reg  [31:0] curr_cluster = 0 , curr_cluster_t;    // current reading cluster number

wire [ 6:0] curr_cluster_fat_offset;
wire [24:0] curr_cluster_fat_no;
assign {curr_cluster_fat_no,curr_cluster_fat_offset} = curr_cluster;

wire [ 7:0] curr_cluster_fat_offset_fat16;
wire [23:0] curr_cluster_fat_no_fat16;
assign {curr_cluster_fat_no_fat16,curr_cluster_fat_offset_fat16} = curr_cluster;

reg  [31:0] target_cluster = 0;           // target cluster number item in FAT32 table
reg  [15:0] target_cluster_fat16 = 16'h0; // target cluster number item in FAT16 table
reg  [ 7:0] cluster_sector_offset=8'h0 , cluster_sector_offset_t;   // current sector number in cluster

reg  [31:0] file_cluster = 0;
reg  [31:0] file_size = 0;

reg  [ 7:0] cluster_size = 0 , cluster_size_t;
reg  [31:0] first_fat_sector_no = 0 , first_fat_sector_no_t;
reg  [31:0] first_data_sector_no= 0 , first_data_sector_no_t;

reg         search_fat = 1'b0;

localparam [2:0] RESET         = 3'd0,
                 SEARCH_MBR    = 3'd1,
                 SEARCH_DBR    = 3'd2,
                 LS_ROOT_FAT16 = 3'd3,
                 LS_ROOT_FAT32 = 3'd4,
                 READ_A_FILE   = 3'd5,
                 DONE          = 3'd6;

reg        [2:0] filesystem_state = RESET;

localparam [1:0] UNASSIGNED = 2'd0,
                 UNKNOWN    = 2'd1,
                 FAT16      = 2'd2,
                 FAT32      = 2'd3;

reg        [1:0] filesystem = UNASSIGNED,
                 filesystem_parsed;

//enum logic [2:0] {RESET, SEARCH_MBR, SEARCH_DBR, LS_ROOT_FAT16, LS_ROOT_FAT32, READ_A_FILE, DONE} filesystem_state = RESET;
//enum logic [1:0] {UNASSIGNED, UNKNOWN, FAT16, FAT32} filesystem=UNASSIGNED, filesystem_parsed;

assign filesystem_type = filesystem;



//----------------------------------------------------------------------------------------------------------------------
// loop variables
integer ii, i;


//----------------------------------------------------------------------------------------------------------------------
// store MBR or DBR fields
//----------------------------------------------------------------------------------------------------------------------
reg [ 7:0] sector_content [0:511];
initial for (ii=0; ii<512; ii=ii+1) sector_content[ii] = 0;

always @ (posedge clk)
    if (rvalid)
        sector_content[raddr] <= rdata;



//----------------------------------------------------------------------------------------------------------------------
// parse MBR or DBR fields
//----------------------------------------------------------------------------------------------------------------------
wire        is_boot_sector     = ( {sector_content['h1FE],sector_content['h1FF]}==16'h55AA );
wire        is_dbr             =    sector_content[0]==8'hEB || sector_content[0]==8'hE9;
wire [31:0] dbr_sector_no      =   {sector_content['h1C9],sector_content['h1C8],sector_content['h1C7],sector_content['h1C6]};
wire [15:0] bytes_per_sector   =   {sector_content['hC],sector_content['hB]};
wire [ 7:0] sector_per_cluster =    sector_content['hD];
wire [15:0] resv_sectors       =   {sector_content['hF],sector_content['hE]};
wire [ 7:0] number_of_fat      =    sector_content['h10];
wire [15:0] rootdir_itemcount  =   {sector_content['h12],sector_content['h11]};   // root dir item count (FAT16 Only)

reg  [31:0] sectors_per_fat = 0;
reg  [31:0] root_cluster    = 0;

always @ (*) begin    
    sectors_per_fat   = {16'h0, sector_content['h17], sector_content['h16]};
    root_cluster      = 0;
    if(sectors_per_fat>0) begin                     // FAT16 case
        filesystem_parsed = FAT16;
    end else if(sector_content['h56]==8'h32) begin  // FAT32 case
        filesystem_parsed = FAT32;
        sectors_per_fat   = {sector_content['h27],sector_content['h26],sector_content['h25],sector_content['h24]};
        root_cluster      = {sector_content['h2F],sector_content['h2E],sector_content['h2D],sector_content['h2C]};
    end else begin   // Unknown FileSystem
        filesystem_parsed = UNKNOWN;
    end
end



//----------------------------------------------------------------------------------------------------------------------
// main FSM
//----------------------------------------------------------------------------------------------------------------------
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        read_start <= 1'b0;
        read_sector_no <= 0;
        filesystem_state <= RESET;
        filesystem <= UNASSIGNED;
        search_fat <= 1'b0;
        cluster_size <= 8'h0;
        first_fat_sector_no   <= 0;
        first_data_sector_no  <= 0;
        curr_cluster          <= 0;
        cluster_sector_offset <= 8'h0;
        rootdir_sector        <= 0;
        rootdir_sectorcount   <= 16'h0;
    end else begin
        cluster_size_t = cluster_size;
        first_fat_sector_no_t  = first_fat_sector_no;
        first_data_sector_no_t = first_data_sector_no;
        curr_cluster_t = curr_cluster;
        cluster_sector_offset_t = cluster_sector_offset;
        rootdir_sector_t = rootdir_sector;
        rootdir_sectorcount_t = rootdir_sectorcount;
    
        read_start <= 1'b0;
        
        if (read_done) begin
            case(filesystem_state)
            SEARCH_MBR :    if(is_boot_sector) begin
                                filesystem_state <= SEARCH_DBR;
                                if(~is_dbr) read_sector_no <= dbr_sector_no;
                            end else begin
                                read_sector_no <= read_sector_no + 1;
                            end
            SEARCH_DBR :    if(is_boot_sector && is_dbr ) begin
                                if(bytes_per_sector!=16'd512) begin
                                    filesystem_state <= DONE;
                                end else begin
                                    filesystem <= filesystem_parsed;
                                    if(filesystem_parsed==FAT16) begin
                                        cluster_size_t        = sector_per_cluster;
                                        first_fat_sector_no_t = read_sector_no + resv_sectors;
                                        
                                        rootdir_sectorcount_t = rootdir_itemcount / (16'd512/16'd32);
                                        rootdir_sector_t      = first_fat_sector_no_t + sectors_per_fat * number_of_fat;
                                        first_data_sector_no_t= rootdir_sector_t + rootdir_sectorcount_t - cluster_size_t*2;
                                        
                                        cluster_sector_offset_t = 8'h0;
                                        read_sector_no      <= rootdir_sector_t + cluster_sector_offset_t;
                                        filesystem_state <= LS_ROOT_FAT16;
                                    end else if(filesystem_parsed==FAT32) begin
                                        cluster_size_t        = sector_per_cluster;
                                        first_fat_sector_no_t = read_sector_no + resv_sectors;
                                        
                                        first_data_sector_no_t= first_fat_sector_no_t + sectors_per_fat * number_of_fat - cluster_size_t * 2;
                                        
                                        curr_cluster_t        = root_cluster;
                                        cluster_sector_offset_t = 8'h0;
                                        read_sector_no      <= first_data_sector_no_t + cluster_size_t * curr_cluster_t + cluster_sector_offset_t;
                                        filesystem_state <= LS_ROOT_FAT32;
                                    end else begin
                                        filesystem_state <= DONE;
                                    end
                                end
                            end
            LS_ROOT_FAT16 :     if(file_found) begin
                                    curr_cluster_t = file_cluster;
                                    cluster_sector_offset_t = 8'h0;
                                    read_sector_no <= first_data_sector_no_t + cluster_size_t * curr_cluster_t + cluster_sector_offset_t;
                                    filesystem_state <= READ_A_FILE;
                                end else if(cluster_sector_offset_t<rootdir_sectorcount_t) begin
                                    cluster_sector_offset_t = cluster_sector_offset_t + 8'd1;
                                    read_sector_no <= rootdir_sector_t + cluster_sector_offset_t;
                                end else begin
                                    filesystem_state <= DONE;   // cant find target file
                                end
            LS_ROOT_FAT32 : if(~search_fat) begin
                                if(file_found) begin
                                    curr_cluster_t = file_cluster;
                                    cluster_sector_offset_t = 8'h0;
                                    read_sector_no <= first_data_sector_no_t + cluster_size_t * curr_cluster_t + cluster_sector_offset_t;
                                    filesystem_state <= READ_A_FILE;
                                end else if(cluster_sector_offset_t<(cluster_size_t-1)) begin
                                    cluster_sector_offset_t = cluster_sector_offset_t + 8'd1;
                                    read_sector_no <= first_data_sector_no_t + cluster_size_t * curr_cluster_t + cluster_sector_offset_t;
                                end else begin   // read FAT to get next cluster
                                    search_fat <= 1'b1;
                                    cluster_sector_offset_t = 8'h0;
                                    read_sector_no <= first_fat_sector_no_t + curr_cluster_fat_no;
                                end
                            end else begin
                                search_fat <= 1'b0;
                                cluster_sector_offset_t = 8'h0;
                                if(target_cluster=='h0FFF_FFFF || target_cluster=='h0FFF_FFF8 || target_cluster=='hFFFF_FFFF || target_cluster<2) begin
                                    filesystem_state <= DONE;   // cant find target file
                                end else begin
                                    curr_cluster_t = target_cluster;
                                    read_sector_no <= first_data_sector_no_t + cluster_size_t * curr_cluster_t + cluster_sector_offset_t;
                                end
                            end
            READ_A_FILE  : 
                            if(~search_fat) begin
                                if(cluster_sector_offset_t<(cluster_size_t-1)) begin
                                    cluster_sector_offset_t = cluster_sector_offset_t + 8'd1;
                                    read_sector_no <= first_data_sector_no_t + cluster_size_t * curr_cluster_t + cluster_sector_offset_t;
                                end else begin   // read FAT to get next cluster
                                    search_fat <= 1'b1;
                                    cluster_sector_offset_t = 8'h0;
                                    read_sector_no <= first_fat_sector_no_t + (filesystem==FAT16 ? curr_cluster_fat_no_fat16 : curr_cluster_fat_no);
                                end
                            end else begin
                                search_fat <= 1'b0;
                                cluster_sector_offset_t = 8'h0;
                                if(filesystem==FAT16) begin
                                    if(target_cluster_fat16>=16'hFFF0 || target_cluster_fat16<16'h2) begin
                                        filesystem_state <= DONE;   // read to the end of file, done
                                    end else begin
                                        curr_cluster_t = {16'h0,target_cluster_fat16};
                                        read_sector_no <= first_data_sector_no_t + cluster_size_t * curr_cluster_t + cluster_sector_offset_t;
                                    end
                                end else begin
                                    if(target_cluster=='h0FFF_FFFF || target_cluster=='h0FFF_FFF8 || target_cluster=='hFFFF_FFFF || target_cluster<2) begin
                                        filesystem_state <= DONE;   // read to the end of file, done
                                    end else begin
                                        curr_cluster_t = target_cluster;
                                        read_sector_no <= first_data_sector_no_t + cluster_size_t * curr_cluster_t + cluster_sector_offset_t;
                                    end
                                end
                            end
            endcase
        end else begin
            case (filesystem_state)
                RESET         : filesystem_state  <= SEARCH_MBR;
                SEARCH_MBR    : read_start <= 1'b1;
                SEARCH_DBR    : read_start <= 1'b1;
                LS_ROOT_FAT16 : read_start <= 1'b1;
                LS_ROOT_FAT32 : read_start <= 1'b1;
                READ_A_FILE   : read_start <= 1'b1;
                //DONE          : $finish;
            endcase
        end
        
        cluster_size <= cluster_size_t;
        first_fat_sector_no <= first_fat_sector_no_t;
        first_data_sector_no <= first_data_sector_no_t;
        curr_cluster <= curr_cluster_t;
        cluster_sector_offset <= cluster_sector_offset_t;
        rootdir_sector <= rootdir_sector_t;
        rootdir_sectorcount <= rootdir_sectorcount_t;
    end


// --- ND-120 project modification (10-JUL-2026): the original SIMULATE-mode
// "$finish on DONE" generate block was removed here (see file header), and
// the DONE state / file size are exported instead.
assign scan_done       = (filesystem_state == DONE);
assign found_file_size = file_size;




//----------------------------------------------------------------------------------------------------------------------
// capture data in FAT table
//----------------------------------------------------------------------------------------------------------------------
always @ (posedge clk or negedge rstn) begin
    if(~rstn) begin
        target_cluster <= 0;
        target_cluster_fat16 <= 16'h0;
    end else begin
        if(search_fat && rvalid) begin
            if(filesystem==FAT16) begin
                if(raddr[8:1]==curr_cluster_fat_offset_fat16)
                    target_cluster_fat16[8*raddr[0] +: 8] <= rdata;
            end else if(filesystem==FAT32) begin
                if(raddr[8:2]==curr_cluster_fat_offset)
                    target_cluster[8*raddr[1:0] +: 8] <= rdata;
            end
        end
    end
end


sd_reader #(
    .CLK_DIV    ( CLK_DIV        ),
    .SIMULATE   ( SIMULATE       )
) u_sd_reader (
    .rstn       ( rstn           ),
    .clk        ( clk            ),
    .sdclk      ( sdclk          ),
    .sdcmd_i    ( sdcmd_i        ),
    .sdcmd_o    ( sdcmd_o        ),
    .sdcmd_oe   ( sdcmd_oe       ),
    .sddat0     ( sddat0         ),
    .card_type  ( card_type      ),
    .card_stat  ( card_stat      ),
    .rstart     ( read_start     ),
    .rsector    ( read_sector_no ),
    .rbusy      (                ),
    .rdone      ( read_done      ),
    .outen      ( rvalid         ),
    .outaddr    ( raddr          ),
    .outbyte    ( rdata          )
);



//----------------------------------------------------------------------------------------------------------------------
// parse root dir
//----------------------------------------------------------------------------------------------------------------------
reg         fready = 1'b0;            // a file is find when fready = 1
reg  [ 7:0] fnamelen = 0;
reg  [15:0] fcluster = 0;
reg  [31:0] fsize = 0;
reg  [ 7:0] fname [0:51];
reg  [ 7:0] file_name [0:51];
reg         isshort=1'b0, islongok=1'b0, islong=1'b0, longvalid=1'b0;
reg         isshort_t   , islongok_t   , islong_t   , longvalid_t   ;
reg  [ 5:0] longno = 6'h0 , longno_t;
reg  [ 7:0] lastchar = 8'h0;
reg  [ 7:0] fdtnamelen = 8'h0 , fdtnamelen_t;
reg  [ 7:0] sdtnamelen = 8'h0 , sdtnamelen_t;
reg  [ 7:0] file_namelen = 8'h0;
reg  [15:0] file_1st_cluster = 16'h0 , file_1st_cluster_t;
reg  [31:0] file_1st_size = 0 , file_1st_size_t;
// ND-120 mod: entry date + directory flag
reg  [15:0] file_1st_date = 16'h0 , file_1st_date_t;
reg         entry_isdir = 1'b0;
reg  [15:0] fdate = 16'h0;
reg         fdir = 1'b0;

initial for(i=0;i<52;i=i+1) begin file_name[i]=8'h0; fname[i]=8'h0; end

always @ (posedge clk or negedge rstn) begin
    if(~rstn) begin
        fready<=1'b0;  fnamelen<=8'h0; file_namelen<=8'h0;
        fcluster<=16'h0;  fsize<=0;
        fdate<=16'h0; fdir<=1'b0; file_1st_date<=16'h0; entry_isdir<=1'b0;
        for(i=0;i<52;i=i+1) begin file_name[i]<=8'h0; fname[i]<=8'h0; end
        
        {isshort, islongok, islong, longvalid} <= 4'b0000;
        
        longno     <= 6'h0;
        lastchar   <= 8'h0;
        fdtnamelen <= 8'h0;
        sdtnamelen <= 8'h0;
        file_1st_cluster <= 16'h0;
        file_1st_size <= 0;
    end else begin
        {isshort_t, islongok_t, islong_t, longvalid_t} = {isshort, islongok, islong, longvalid};
        longno_t = longno;
        fdtnamelen_t = fdtnamelen;
        sdtnamelen_t = sdtnamelen;
        file_1st_cluster_t = file_1st_cluster;
        file_1st_size_t = file_1st_size;
        file_1st_date_t = file_1st_date;
        
        fready<=1'b0;  fnamelen<=8'h0;
        for(i=0;i<52;i=i+1) fname[i]<=8'h0;
        fcluster<=16'h0;  fsize<=0;
        fdate<=16'h0; fdir<=1'b0;
        
        if( rvalid && (filesystem_state==LS_ROOT_FAT16||filesystem_state==LS_ROOT_FAT32) && ~search_fat ) begin
            case (raddr[4:0])
                5'h18 :    file_1st_date_t[ 0+:8] = rdata;   // ND-120 mod: write date
                5'h19 :    file_1st_date_t[ 8+:8] = rdata;
                5'h1A : file_1st_cluster_t[ 0+:8] = rdata;
                5'h1B : file_1st_cluster_t[ 8+:8] = rdata;
                5'h1C :    file_1st_size_t[ 0+:8] = rdata;
                5'h1D :    file_1st_size_t[ 8+:8] = rdata;
                5'h1E :    file_1st_size_t[16+:8] = rdata;
                5'h1F :    file_1st_size_t[24+:8] = rdata;
            endcase
            
            if(raddr[4:0]==5'h0) begin
                {islongok_t, isshort_t} = 2'b00;
                fdtnamelen_t = 8'h0;  sdtnamelen_t=8'h0;
                
                if(rdata!=8'hE5 && rdata!=8'h2E && rdata!=8'h00) begin
                    if(islong_t && longno_t==6'h1)
                        islongok_t = 1'b1;
                    else
                        isshort_t = 1'b1;
                end
                
                if(rdata[7]==1'b0 && ~islongok_t) begin
                    if(rdata[6]) begin
                        {islong_t,longvalid_t} = 2'b11;
                        longno_t = rdata[5:0];
                    end else if(islong_t) begin
                        if(longno_t>6'h1 && (rdata[5:0]+6'h1==longno_t) ) begin
                            islong_t = 1'b1;
                            longno_t = rdata[5:0];
                        end else begin
                            islong_t = 1'b0;
                        end
                    end else
                        islong_t = 1'b0;
                end else
                    islong_t = 1'b0;
            end else if(raddr[4:0]==5'hB) begin
                if(rdata!=8'h0F)
                    islong_t = 1'b0;
                // ND-120 mod: accept plain files (0x20) AND subdirectories (0x10)
                if(rdata!=8'h20 && rdata!=8'h10)
                    {isshort_t, islongok_t} = 2'b00;
                entry_isdir <= (rdata==8'h10);
            end else if(raddr[4:0]==5'h1F) begin
                if(islongok_t && longvalid_t || isshort_t) begin
                    fready <= 1'b1;
                    fnamelen <= file_namelen;
                    for(i=0;i<52;i=i+1) fname[i] <= (i<file_namelen) ? file_name[i] : 8'h0;
                    fcluster <= file_1st_cluster_t;
                    fsize <= file_1st_size_t;
                    fdate <= file_1st_date_t;   // ND-120 mod
                    fdir <= entry_isdir;        // ND-120 mod
                end
            end
            
            if(islong_t) begin
                if(raddr[4:0]>5'h0&&raddr[4:0]<5'hB || raddr[4:0]>=5'hE&&raddr[4:0]<5'h1A || raddr[4:0]>=5'h1C)begin
                    if((raddr[4:0]<5'hB) ? raddr[0] : ~raddr[0]) begin   // parens: yosys lexes "'hB ?" as a wildcard literal (ND-120 mod)
                        lastchar <= rdata;
                        fdtnamelen_t = fdtnamelen_t + 8'd1;
                    end else begin
                        //automatic logic [15:0] unicode = {rdata,lastchar};
                        if({rdata,lastchar} == 16'h0000) begin
                            file_namelen <= fdtnamelen_t-8'd1 + (longno_t-8'd1)*8'd13;
                        end else if({rdata,lastchar} != 16'hFFFF) begin
                            if(rdata == 8'h0) begin
                                file_name[fdtnamelen_t-8'd1+(longno_t-8'd1)*8'd13] <= (lastchar>=8'h61 && lastchar<=8'h7A) ? lastchar&8'b11011111 : lastchar; 
                            end else begin
                                longvalid_t = 1'b0;
                            end
                        end
                    end
                end
            end 
            
            if(isshort_t) begin
                if(raddr[4:0]<5'h8) begin
                    if(rdata!=8'h20) begin
                        file_name[sdtnamelen_t] <= rdata;
                        sdtnamelen_t = sdtnamelen_t + 8'd1;
                    end
                end else if(raddr[4:0]<5'hB) begin
                    // ND-120 mod: only insert the '.' when an extension
                    // actually follows (upstream gave "NAME." for
                    // extension-less 8.3 names, e.g. directories)
                    if(raddr[4:0]==5'h8 && rdata!=8'h20) begin
                        file_name[sdtnamelen_t] <= 8'h2E;
                        sdtnamelen_t = sdtnamelen_t + 8'd1;
                    end
                    if(rdata!=8'h20) begin
                        file_name[sdtnamelen_t] <= rdata;
                        sdtnamelen_t = sdtnamelen_t + 8'd1;
                    end
                end else if(raddr[4:0]==5'hB) begin
                    file_namelen <= sdtnamelen_t;
                end
            end
            
        end
        
        {isshort, islongok, islong, longvalid} <= {isshort_t, islongok_t, islong_t, longvalid_t};
        longno <= longno_t;
        fdtnamelen <= fdtnamelen_t;
        sdtnamelen <= sdtnamelen_t;
        file_1st_cluster <= file_1st_cluster_t;
        file_1st_size <= file_1st_size_t;
        file_1st_date <= file_1st_date_t;
    end
end



//----------------------------------------------------------------------------------------------------------------------
// compare Target filename with Parsed filename
//----------------------------------------------------------------------------------------------------------------------
// --- ND-120 project modification (10-JUL-2026): compare against the runtime
// target_name port (byte-0-first layout, so the compare is index-aligned)
// instead of the FILE_NAME parameter; target_len==0 never matches (LIST mode).
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        file_found <= 1'b0;
        file_cluster <= 0;
        file_size <= 0;
    end else begin
        if (fready && !fdir && fnamelen==target_len && target_len!=8'd0) begin
            file_found <= 1'b1;
            file_cluster <= fcluster;
            file_size <= fsize;
            for (ii=0; ii<52; ii=ii+1) begin
                if( ii<target_len && fname[ii] != toUpperCase(target_name[ii*8+:8]) ) begin
                    file_found <= 1'b0;
                    file_cluster <= 0;
                    file_size <= 0;
                end
            end
        end
    end

// --- ND-120 project modification (10/11-JUL-2026): export walked dir entries
assign dir_entry_valid  = fready;
assign dir_entry_len    = fnamelen;
assign dir_entry_size   = fsize;
assign dir_entry_date   = fdate;
assign dir_entry_is_dir = fdir;
// (mod 5) absolute first data sector of the found file (contiguity is the
// caller's responsibility - see SD-FAT/README.md, in-place rewrite)
assign found_file_first_sector = first_data_sector_no + cluster_size * file_cluster;
generate genvar dk;
    for (dk=0; dk<52; dk=dk+1) begin : flatten_dir_entry_name
        assign dir_entry_name[8*dk +: 8] = fname[dk];
    end
endgenerate



//----------------------------------------------------------------------------------------------------------------------
// output file content
//----------------------------------------------------------------------------------------------------------------------
reg [31:0] fptr = 0;

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        fptr <= 0;
        {outen,outbyte} <= 0;
    end else begin
        if(rvalid && filesystem_state==READ_A_FILE && ~search_fat && fptr<file_size) begin
            fptr <= fptr + 1;
            {outen,outbyte} <= {1'b1,rdata};
        end else
            {outen,outbyte} <= 0;
    end


endmodule
