#pragma once

#include <string>

namespace util {

// Supports filename and RFC 5987 filename*, preferring filename*.
bool HasVideoFilename(const std::string& header_value);

}  // namespace util
