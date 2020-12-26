// Copyright (C) 2020 Joel Rosdahl and other contributors
//
// See doc/AUTHORS.adoc for a complete list of contributors.
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with
// this program; if not, write to the Free Software Foundation, Inc., 51
// Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

#include "Win32Util.hpp"

#include "Util.hpp"

#include "third_party/win32/errmap.h"

#include <chrono>
#include <thread>

namespace {

template<typename Signature>
Signature*
get_proc_address(HMODULE module_handle, const char* proc_name)
{
#ifdef __GNUC__
#  pragma GCC diagnostic push
#  if __GNUC__ >= 8 && !defined(__clang__)
#    pragma GCC diagnostic ignored "-Wcast-function-type"
#  endif
#endif

  return reinterpret_cast<Signature*>(GetProcAddress(module_handle, proc_name));

#ifdef __GNUC__
#  pragma GCC diagnostic pop
#endif
}

} // namespace

namespace Win32Util {

std::string
add_exe_suffix(const std::string& path)
{
  auto ext = Util::to_lowercase(Util::get_extension(path));
  if (ext == ".exe" || ext == ".bat" || ext == ".sh") {
    return path;
  } else {
    return path + ".exe";
  }
}

std::string
error_message(DWORD error_code)
{
  LPSTR buffer;
  size_t size =
    FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM
                     | FORMAT_MESSAGE_IGNORE_INSERTS,
                   nullptr,
                   error_code,
                   MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                   reinterpret_cast<LPSTR>(&buffer),
                   0,
                   nullptr);
  std::string message(buffer, size);
  LocalFree(buffer);
  return message;
}

std::string
argv_to_string(const char* const* argv, const std::string& prefix)
{
  std::string result;
  size_t i = 0;
  const char* arg = prefix.empty() ? argv[i++] : prefix.c_str();

  do {
    if (strpbrk(arg, "\" ") == nullptr) {
      // This argument does not require escaping for CreateProcess().
      result.append(arg);
      result.push_back(' ');
      continue;
    }

    result.push_back('"');
    size_t consecutive_backslash_count = 0;
    const char* span_begin = arg;
    for (const char* it = arg; *it != '\0'; ++it) {
      switch (*it) {
      case '\\':
        ++consecutive_backslash_count;
        break;
      case '"':
        result.append(span_begin, it);
        result.append(consecutive_backslash_count + 1, '\\');
        span_begin = it;
        consecutive_backslash_count = 0;
        break;
      default:
        consecutive_backslash_count = 0;
        break;
      }
    }
    result.append(span_begin);
    result.append(consecutive_backslash_count, '\\');
    result.push_back('"');
    result.push_back(' ');
  } while ((arg = argv[i++]));

  // Remove extraneous space
  result.pop_back();

  return result;
}

NTSTATUS
get_last_ntstatus()
{
  static auto* rtl_get_last_ntstatus_fn =
    get_proc_address<NTSTATUS NTAPI(void)>(GetModuleHandleA("ntdll.dll"),
                                           "RtlGetLastNtStatus");
  return rtl_get_last_ntstatus_fn();
}

DWORD
ntstatus_to_winerror(NTSTATUS ntstatus)
{
  static auto* rtl_nt_status_to_dos_error_fn =
    get_proc_address<ULONG NTAPI(NTSTATUS)>(GetModuleHandleA("ntdll.dll"),
                                            "RtlNtStatusToDosError");
  switch (ntstatus) {
  case STATUS_DELETE_PENDING:
    // RtlNtStatusToDosError translation is lossy, and maps this code to
    // ERROR_ACCESS_DENIED. We can do better.
    return ERROR_DELETE_PENDING;
  default:
    return rtl_nt_status_to_dos_error_fn(ntstatus);
  }
}

int
winerror_to_errno(DWORD winerror)
{
  return ::winerror_to_errno(winerror);
}

} // namespace Win32Util

// From: https://stackoverflow.com/a/58162122/262458
#ifdef _MSC_VER
int
gettimeofday(struct timeval* tp, struct timezone* /*tzp*/)
{
  namespace sc = std::chrono;
  sc::system_clock::duration d = sc::system_clock::now().time_since_epoch();
  sc::seconds s = sc::duration_cast<sc::seconds>(d);
  tp->tv_sec = static_cast<long>(s.count());
  tp->tv_usec =
    static_cast<long>(sc::duration_cast<sc::microseconds>(d - s).count());

  return 0;
}
#endif

void
usleep(int64_t usec)
{
  std::this_thread::sleep_for(std::chrono::microseconds(usec));
}

struct tm*
localtime_r(time_t* _clock, struct tm* _result)
{
  struct tm* p = localtime(_clock);

  if (p)
    *(_result) = *p;

  return p;
}

// From: https://stackoverflow.com/a/40160038/262458
#ifdef _MSC_VER
int
vasprintf(char** strp, const char* fmt, va_list ap)
{
  // _vscprintf tells you how big the buffer needs to be
  int len = _vscprintf(fmt, ap);
  if (len == -1) {
    return -1;
  }
  size_t size = (size_t)len + 1;
  char* str = static_cast<char*>(malloc(size));
  if (!str) {
    return -1;
  }
  // vsprintf_s is the "secure" version of vsprintf
  int r = vsprintf_s(str, len + 1, fmt, ap);
  if (r == -1) {
    free(str);
    return -1;
  }
  *strp = str;
  return r;
}
#endif

// Also from: https://stackoverflow.com/a/40160038/262458
#ifdef _MSC_VER
int
asprintf(char** strp, const char* fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  int r = vasprintf(strp, fmt, ap);
  va_end(ap);
  return r;
}
#endif
