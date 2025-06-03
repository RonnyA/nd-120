#
# Makefile for MC68705P3 Microcontroller Firmware Emulator
# Builds emulator and test suite for ND-120 Operator Panel Controller
#

# Compiler and flags
CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2 -g
INCLUDES = -I.
LDFLAGS = 
LIBS = 

# Debug build flags
DEBUG_CFLAGS = -Wall -Wextra -std=c99 -O0 -g -DDEBUG -fsanitize=address
DEBUG_LDFLAGS = -fsanitize=address

# Source files
EMULATOR_SRCS = p3.c
TEST_SRCS = test_p3.c
HEADERS = p3.h

# Object files
EMULATOR_OBJS = $(EMULATOR_SRCS:.c=.o)
TEST_OBJS = $(TEST_SRCS:.c=.o)

# Target executables
EMULATOR_TARGET = mc68705_emulator
TEST_TARGET = mc68705_test
DEBUG_TARGET = mc68705_emulator_debug

# Default target
all: $(EMULATOR_TARGET) $(TEST_TARGET)

# Emulator executable
$(EMULATOR_TARGET): $(EMULATOR_OBJS)
	@echo "Building MC68705P3 Emulator..."
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)
	@echo "Emulator built successfully: $@"

# Test suite executable
$(TEST_TARGET): $(TEST_OBJS)
	@echo "Building Test Suite..."
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)
	@echo "Test suite built successfully: $@"

# Debug build
debug: CFLAGS = $(DEBUG_CFLAGS)
debug: LDFLAGS = $(DEBUG_LDFLAGS)
debug: $(DEBUG_TARGET)

$(DEBUG_TARGET): $(EMULATOR_OBJS)
	@echo "Building Debug Version..."
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)
	@echo "Debug build completed: $@"

# Object file compilation
%.o: %.c $(HEADERS)
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Run the emulator
run: $(EMULATOR_TARGET)
	@echo "Running MC68705P3 Emulator..."
	./$(EMULATOR_TARGET)

# Run the test suite
test: $(TEST_TARGET)
	@echo "Running Test Suite..."
	./$(TEST_TARGET)

# Run with valgrind for memory checking
valgrind: $(EMULATOR_TARGET)
	@echo "Running with Valgrind..."
	valgrind --leak-check=full --show-leak-kinds=all ./$(EMULATOR_TARGET)

# Static analysis with cppcheck
analyze:
	@echo "Running static analysis..."
	cppcheck --enable=all --std=c99 --suppress=missingIncludeSystem $(EMULATOR_SRCS) $(TEST_SRCS)

# Generate documentation
docs:
	@echo "Generating documentation..."
	doxygen Doxyfile || echo "Doxygen not found, skipping documentation generation"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f *.o $(EMULATOR_TARGET) $(TEST_TARGET) $(DEBUG_TARGET)
	rm -rf *.dSYM/  # macOS debug symbols
	rm -f core.*    # Core dumps

# Clean everything including documentation
distclean: clean
	@echo "Cleaning all generated files..."
	rm -rf docs/
	rm -f *.log
	rm -f *.trace

# Install (copy to system directory)
install: $(EMULATOR_TARGET)
	@echo "Installing MC68705P3 Emulator..."
	mkdir -p /usr/local/bin
	cp $(EMULATOR_TARGET) /usr/local/bin/
	chmod 755 /usr/local/bin/$(EMULATOR_TARGET)
	@echo "Installation complete"

# Uninstall
uninstall:
	@echo "Uninstalling MC68705P3 Emulator..."
	rm -f /usr/local/bin/$(EMULATOR_TARGET)
	@echo "Uninstallation complete"

# Create source distribution
dist:
	@echo "Creating source distribution..."
	mkdir -p mc68705_emulator_src
	cp $(EMULATOR_SRCS) $(TEST_SRCS) $(HEADERS) Makefile README.md mc68705_emulator_src/
	tar -czf mc68705_emulator_src.tar.gz mc68705_emulator_src/
	rm -rf mc68705_emulator_src/
	@echo "Source distribution created: mc68705_emulator_src.tar.gz"

# Performance profiling
profile: CFLAGS += -pg
profile: $(EMULATOR_TARGET)
	@echo "Running performance profile..."
	./$(EMULATOR_TARGET)
	gprof $(EMULATOR_TARGET) gmon.out > profile.txt
	@echo "Profile generated: profile.txt"

# Code coverage
coverage: CFLAGS += --coverage
coverage: LDFLAGS += --coverage
coverage: $(TEST_TARGET)
	@echo "Running code coverage analysis..."
	./$(TEST_TARGET)
	gcov $(TEST_SRCS)
	@echo "Coverage analysis complete"

# Help target
help:
	@echo "MC68705P3 Microcontroller Emulator Build System"
	@echo "================================================"
	@echo ""
	@echo "Available targets:"
	@echo "  all         - Build emulator and test suite (default)"
	@echo "  emulator    - Build only the emulator"
	@echo "  test        - Build and run test suite"
	@echo "  debug       - Build debug version with AddressSanitizer"
	@echo "  run         - Run the emulator"
	@echo "  valgrind    - Run with Valgrind memory checking"
	@echo "  analyze     - Run static analysis with cppcheck"
	@echo "  docs        - Generate documentation with Doxygen"
	@echo "  clean       - Remove build artifacts"
	@echo "  distclean   - Remove all generated files"
	@echo "  install     - Install to system directory"
	@echo "  uninstall   - Remove from system directory"
	@echo "  dist        - Create source distribution"
	@echo "  profile     - Build and run performance profiling"
	@echo "  coverage    - Run code coverage analysis"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Build configuration:"
	@echo "  CC          = $(CC)"
	@echo "  CFLAGS      = $(CFLAGS)"
	@echo "  INCLUDES    = $(INCLUDES)"
	@echo ""

# Phony targets
.PHONY: all clean distclean run test debug valgrind analyze docs install uninstall dist profile coverage help

# Additional build configurations for different targets

# Cross-compilation for embedded systems (example for ARM)
arm: CC = arm-linux-gnueabihf-gcc
arm: CFLAGS += -march=armv7-a
arm: $(EMULATOR_TARGET)

# Windows cross-compilation (with MinGW)
windows: CC = x86_64-w64-mingw32-gcc
windows: EMULATOR_TARGET = p3.exe
windows: TEST_TARGET = mc68705_test.exe
windows: $(EMULATOR_TARGET) $(TEST_TARGET)

# Optimized release build
release: CFLAGS = -Wall -Wextra -std=c99 -O3 -DNDEBUG -march=native
release: $(EMULATOR_TARGET)
	@echo "Optimized release build complete"
	strip $(EMULATOR_TARGET)

# Continuous integration build
ci: clean analyze $(EMULATOR_TARGET) $(TEST_TARGET) test
	@echo "CI build and test complete"

# Development build with all warnings
dev: CFLAGS += -Wpedantic -Wconversion -Wshadow -Wformat=2
dev: $(EMULATOR_TARGET) $(TEST_TARGET)

# Print build information
info:
	@echo "Build Information:"
	@echo "=================="
	@echo "Compiler: $(CC)"
	@echo "Version: $(shell $(CC) --version | head -1)"
	@echo "CFLAGS: $(CFLAGS)"
	@echo "Sources: $(EMULATOR_SRCS) $(TEST_SRCS)"
	@echo "Headers: $(HEADERS)"
	@echo "Targets: $(EMULATOR_TARGET) $(TEST_TARGET)"