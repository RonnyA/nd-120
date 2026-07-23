/**************************************************************************
** NDConsoleScript - see NDConsoleScript.h for the rationale.             **
***************************************************************************/

#include "NDConsoleScript.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

// Decode C-style escapes in `src` into a freshly malloc'd byte buffer.
// Supported: \r \n \t \f \b \0 \\ \e(=ESC 033) and octal \NNN (1..3 digits).
// Any other \x is passed through literally (the backslash is dropped, the
// following char kept) so an accidental escape never silently swallows data.
// The returned buffer is NUL-terminated for convenience but MAY contain
// embedded NULs if the script used \0 - the harness feeds it as a C string,
// so \0 would end injection early; that is the caller's problem to avoid.
static char *decode_escapes(const char *src)
{
	size_t n = strlen(src);
	// Decoded output is never longer than the input, +1 for the terminator.
	char *out = (char *)malloc(n + 1);
	if (!out)
		return NULL;

	size_t w = 0;
	for (size_t i = 0; i < n; i++)
	{
		char c = src[i];
		if (c != '\\' || i + 1 >= n)
		{
			out[w++] = c; // ordinary byte, or a trailing lone backslash
			continue;
		}

		char e = src[++i]; // char after the backslash
		switch (e)
		{
		case 'r': out[w++] = '\r'; break; // carriage return - OPCOM line submit
		case 'n': out[w++] = '\n'; break;
		case 't': out[w++] = '\t'; break;
		case 'f': out[w++] = '\f'; break;
		case 'b': out[w++] = '\b'; break;
		case 'e': out[w++] = (char)033; break; // ESC (escape sequences to monitor)
		case '\\': out[w++] = '\\'; break;
		case '0': case '1': case '2': case '3':
		case '4': case '5': case '6': case '7':
		{
			// Octal escape \NNN (1..3 octal digits) - lets a script embed any
			// byte value, e.g. \033 for ESC or control chars the shell mangles.
			int val = e - '0';
			int digits = 1;
			while (digits < 3 && i + 1 < n && src[i + 1] >= '0' && src[i + 1] <= '7')
			{
				val = (val << 3) | (src[++i] - '0');
				digits++;
			}
			out[w++] = (char)(val & 0xFF);
			break;
		}
		default:
			out[w++] = e; // unknown escape: keep the char, drop the backslash
			break;
		}
	}
	out[w] = '\0';
	return out;
}

// Read the entire file at `path` into a freshly malloc'd, NUL-terminated
// buffer. Returns NULL (and leaves errno set) on any failure.
static char *read_whole_file(const char *path)
{
	FILE *f = fopen(path, "rb");
	if (!f)
		return NULL;

	if (fseek(f, 0, SEEK_END) != 0)
	{
		fclose(f);
		return NULL;
	}
	long sz = ftell(f);
	if (sz < 0)
	{
		fclose(f);
		return NULL;
	}
	rewind(f);

	char *buf = (char *)malloc((size_t)sz + 1);
	if (!buf)
	{
		fclose(f);
		return NULL;
	}
	size_t got = fread(buf, 1, (size_t)sz, f);
	fclose(f);
	buf[got] = '\0';
	return buf;
}

const char *nd_console_script_resolve(const char *fallback)
{
	// 1. Inline env string (with escape decoding) - highest precedence.
	const char *inl = getenv("ND120_SCRIPT");
	if (inl && inl[0] != '\0')
	{
		char *decoded = decode_escapes(inl);
		if (decoded)
		{
			fprintf(stderr, "[script] source: ND120_SCRIPT (inline, %zu bytes decoded)\n",
			        strlen(decoded));
			return decoded;
		}
		fprintf(stderr, "[script] ND120_SCRIPT set but decode failed - using default\n");
	}

	// 2. Script file - its raw bytes are the script verbatim.
	const char *path = getenv("ND120_SCRIPT_FILE");
	if (path && path[0] != '\0')
	{
		char *buf = read_whole_file(path);
		if (buf)
		{
			fprintf(stderr, "[script] source: ND120_SCRIPT_FILE=%s (%zu bytes)\n",
			        path, strlen(buf));
			return buf;
		}
		fprintf(stderr, "[script] ND120_SCRIPT_FILE=%s could not be read - using default\n",
		        path);
	}

	// 3. Compiled-in default - behaviour unchanged when neither env is set.
	return fallback;
}
