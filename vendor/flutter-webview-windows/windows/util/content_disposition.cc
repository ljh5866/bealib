#include "content_disposition.h"

#include <cctype>
#include <string_view>

namespace util {
namespace {

std::string ToLowerAscii(std::string_view value) {
  std::string result(value);
  for (char& character : result) {
    character =
        static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
  }
  return result;
}

std::string_view Trim(std::string_view value) {
  while (!value.empty() &&
         std::isspace(static_cast<unsigned char>(value.front()))) {
    value.remove_prefix(1);
  }
  while (!value.empty() &&
         std::isspace(static_cast<unsigned char>(value.back()))) {
    value.remove_suffix(1);
  }
  return value;
}

int HexValue(char character) {
  if (character >= '0' && character <= '9') {
    return character - '0';
  }
  character =
      static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
  if (character >= 'a' && character <= 'f') {
    return character - 'a' + 10;
  }
  return -1;
}

std::string PercentDecode(std::string_view value) {
  std::string result;
  result.reserve(value.size());
  for (size_t index = 0; index < value.size(); ++index) {
    if (value[index] == '%' && index + 2 < value.size()) {
      const int high = HexValue(value[index + 1]);
      const int low = HexValue(value[index + 2]);
      if (high >= 0 && low >= 0) {
        result.push_back(static_cast<char>((high << 4) | low));
        index += 2;
        continue;
      }
    }
    result.push_back(value[index]);
  }
  return result;
}

std::string DecodeParameterValue(std::string_view value, bool is_extended) {
  value = Trim(value);
  std::string unquoted;
  if (value.size() >= 2 && value.front() == '"' && value.back() == '"') {
    value.remove_prefix(1);
    value.remove_suffix(1);
    unquoted.reserve(value.size());
    bool escaped = false;
    for (const char character : value) {
      if (escaped) {
        unquoted.push_back(character);
        escaped = false;
      } else if (character == '\\') {
        escaped = true;
      } else {
        unquoted.push_back(character);
      }
    }
    value = unquoted;
  }

  if (is_extended) {
    const size_t charset_end = value.find('\'');
    if (charset_end != std::string_view::npos) {
      const size_t language_end = value.find('\'', charset_end + 1);
      if (language_end != std::string_view::npos) {
        value.remove_prefix(language_end + 1);
      }
    }
    return PercentDecode(value);
  }
  return std::string(value);
}

std::string FindFilename(const std::string& header_value) {
  std::string regular_filename;
  size_t position = header_value.find(';');
  while (position != std::string::npos && position < header_value.size()) {
    ++position;
    while (position < header_value.size() &&
           std::isspace(static_cast<unsigned char>(header_value[position]))) {
      ++position;
    }

    const size_t name_start = position;
    while (position < header_value.size() && header_value[position] != '=' &&
           header_value[position] != ';') {
      ++position;
    }
    if (position >= header_value.size() || header_value[position] != '=') {
      position = header_value.find(';', position);
      continue;
    }

    const std::string name =
        ToLowerAscii(Trim(std::string_view(header_value)
                              .substr(name_start, position - name_start)));
    ++position;
    const size_t value_start = position;
    bool quoted = false;
    bool escaped = false;
    if (position < header_value.size() && header_value[position] == '"') {
      quoted = true;
      ++position;
    }
    while (position < header_value.size()) {
      const char character = header_value[position];
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (character == '\\') {
          escaped = true;
        } else if (character == '"') {
          ++position;
          break;
        }
      } else if (character == ';') {
        break;
      }
      ++position;
    }

    if (name != "filename" && name != "filename*") {
      position = header_value.find(';', position);
      continue;
    }

    const std::string filename =
        DecodeParameterValue(std::string_view(header_value)
                                 .substr(value_start, position - value_start),
                             name == "filename*");
    if (name == "filename*") {
      return filename;
    }
    if (name == "filename") {
      regular_filename = filename;
    }
    position = header_value.find(';', position);
  }
  return regular_filename;
}

bool HasVideoExtension(std::string_view filename) {
  const std::string lower_filename = ToLowerAscii(Trim(filename));
  const size_t extension_start = lower_filename.rfind('.');
  if (extension_start == std::string::npos) {
    return false;
  }

  const std::string_view extension(lower_filename.data() + extension_start,
                                   lower_filename.size() - extension_start);
  return extension == ".mknvideo" || extension == ".mp4" || extension == ".mkv";
}

}  // namespace

bool HasVideoFilename(const std::string& header_value) {
  return HasVideoExtension(FindFilename(header_value));
}

}  // namespace util
