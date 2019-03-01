#!/bin/bash
##
## Author: Bertrand Benoit <mailto:contact@bertrand-benoit.net>
## Description: Tests all features provided by utilities script.
## Version: 0.1

DEBUG_UTILITIES=1
CATEGORY="tests:general"
ERROR_MESSAGE_EXITS_SCRIPT=0
LOG_CONSOLE_OFF=1

# Ensures utilities path has been defined, and sources it.
[ -z "${SCRIPTS_COMMON_PATH:-}" ] && echo "SCRIPTS_COMMON_PATH environment variable must be defined." >&2 && exit 1
. "$SCRIPTS_COMMON_PATH"

## Defines some constants.
currentDir=$( dirname "$( which "$0" )" )
declare -r miscDir="$currentDir/misc"
declare -r daemonSample="$miscDir/daemonSample"

declare -r ERROR_TEST_FAILURE=200

# usage: enteringTests <test category>
function enteringTests() {
  local _testCategory="$1"
  CATEGORY="tests:$_testCategory"

  info "$_testCategory feature tests - BEGIN"
}

# usage: exitingTests <test category>
function exitingTests() {
  local _testCategory="$1"
  CATEGORY="tests:general"

  info "$_testCategory feature tests - END"
}

## Define Tests functions.
# Logger feature Tests.
testLoggerFeature() {
  enteringTests "logger"

  info "Simple message tests (should not have prefix)"
  info "Info message test"
  warning "Warning message test"
  errorMessage "Error message test" -1 # -1 to avoid automatic exit of the script

  exitingTests "logger"
}

# Robustness Tests.
testLoggerRobustness() {
  local _logLevel _message _sameLine _exitStatus

  enteringTests "robustness"

  _logLevel="$LOG_LEVEL_MESSAGE"
  _message="Simple message"
  _newLine="1"
  _exitStatus="-1"

  # doWriteMessage should NOT be called directly, but user can still do it, ensures robustness on parameters control.
  # Log level
 _doWriteMessage "Broken Log level ..." "$_message" "$_newLine" "$_exitStatus"

  # Message
 _doWriteMessage "$_logLevel" "Message on \
                                several \
                                lines" "$_newLine" "$_exitStatus"

 _doWriteMessage "$_logLevel" "Message on \nseveral \nlines" "$_newLine" "$_exitStatus"
  # New line.
 _doWriteMessage "$_logLevel" "$_message" "Bad value" "$_exitStatus"

  # Exit status.
 _doWriteMessage "$_logLevel" "$_message" "$_newLine" "Bad value"

  exitingTests "robustness"
}

# Environment check feature Tests.
testEnvironmentCheckFeature() {
  local _failureErrorMessage="Environment check feature is broken"

  enteringTests "envCheck"

  info "Checking if user is root ... "
  isRootUser && echo "YES" || echo "NO"

  info "Checking if GNU which is installed ... "
  checkGNUWhich && echo "YES" || echo "NO"

  info "Checking environment ... "
  assertTrue checkEnvironment

  info "Checking LSB ... "
  checkLSB

  info "Checking Locale with no utf-8 LANG ... this must produce a WARNING."
  LANG=en_GB checkLocale && fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking Locale with not installed/existing utf-8 LANG ... this must produce a WARNING."
  LANG=zz_ZZ.UTF-8 checkLocale && fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking Locale with a good LANG defined to en_GB.UTF-8."
  LANG=en_GB.UTF-8 checkLocale || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking Locale with a good LANG defined to en_GB.utf8."
  LANG=en_GB.utf8 checkLocale || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  exitingTests "envCheck"
}

# Conditional Tests.
testConditionalBehaviour() {
  enteringTests "conditional"

  # Script should NOT break because of the pipe status ...
  [ 0 -gt 1 ] || info "fake test ..."

  exitingTests "conditional"
}

# Version feature Tests.
testVersionFeature() {
  local _fileWithVersion _version _fakeVersion
  enteringTests "version"

  _fileWithVersion="$currentDir/../README.md"
  _version=$( getVersion "$_fileWithVersion" )
  _fakeVersion="999.999.999"

  info "scripts-common Utilities version: $_version"
  info "scripts-common Utilities detailed version: $( getDetailedVersion "$_version" "$currentDir/.." )"

  info "Checking getDetailedVersion on NOT existing directory"
  getDetailedVersion "$_version" "$currentDir/NotExistingDirectory" && fail "Version feature is broken" $ERROR_TEST_FAILURE

  info "Checking if $_version is greater than $_fakeVersion ... (should NOT be the case)"
  isVersionGreater "$_version" "$_fakeVersion" && fail "Version feature is broken" $ERROR_TEST_FAILURE

  info "Checking if $_fakeVersion is greater than $_version ... (should be the case)"
  ! isVersionGreater "$_fakeVersion" "$_version" && fail "Version feature is broken" $ERROR_TEST_FAILURE

  exitingTests "version"
}

# Time feature Tests.
testTimeFeature() {
  enteringTests "time"

  info "Testing time feature"
  initializeStartTime
  sleep 1
  info "Uptime: $( getUptime )"

  exitingTests "time"
}

testCheckPathFeature() {
  local _failureErrorMessage="Check path feature is broken"
  local _checkPathRootDir="$DEFAULT_TMP_DIR/checkPathRootDir"
  local _dataFileName="myFile.data"
  local _binFileName="myFile.bin"
  local _subPathDir="myDir"
  local _homeRelativePath="something/not/existing"
  local _pathsToFormatBefore _pathsToFormatAfter

  enteringTests "checkPath"

  # To avoid error when configuration key is not found, switch on this mode.
  MODE_CHECK_CONFIG=1

  # Limit tests, on not existing files.
  info "Checking NOT existing directory, is empty (should answer NO)."
  isEmptyDirectory "$_checkPathRootDir" && fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  updateStructure "$_checkPathRootDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking NOT existing Data file."
  checkDataFile "$_checkPathRootDir/$_dataFileName" && fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking NOT existing Binary file."
  checkBin "$_checkPathRootDir/$_binFileName" && fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking NOT existing Path."
  checkPath "$_checkPathRootDir/$_subPathDir" && fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  # Normal situation.
  touch "$_checkPathRootDir/$_dataFileName" "$_checkPathRootDir/$_binFileName" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  chmod +x "$_checkPathRootDir/$_binFileName" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  updateStructure "$_checkPathRootDir/$_subPathDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking existing directory is empty."
  isEmptyDirectory "$_checkPathRootDir/$_subPathDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking existing Data file."
  checkDataFile "$_checkPathRootDir/$_dataFileName" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking existing Binary file."
  checkBin "$_checkPathRootDir/$_binFileName" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking existing Path."
  checkPath "$_checkPathRootDir/$_subPathDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  # Absolute/Relative path and completePath.
  info "Checking isAbsolutePath function."
  isAbsolutePath "$_checkPathRootDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  isAbsolutePath "$_subPathDir" && fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking isRelativePath function."
  isRelativePath "$_checkPathRootDir" && fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  isRelativePath "$_subPathDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking buildCompletePath function."
  # Absolute path stays unchanged.
  assertEquals "$( buildCompletePath "$_checkPathRootDir" )" "$_checkPathRootDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  # Relative path stays unchanged, if no prepend arguments is specified.
  assertEquals "$( buildCompletePath "$_subPathDir" )" "$_subPathDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  assertEquals "$( buildCompletePath "$_subPathDir" "$_checkPathRootDir" )" "$_subPathDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  # Relative path must be fully completed, with all prepend arguments.
  assertEquals "$( buildCompletePath "$_subPathDir" "$_checkPathRootDir" 1 )" "$_checkPathRootDir/$_subPathDir" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  # Special situation: HOME subsitution.
  info "Checking buildCompletePath function, for ~ substitution with HOME environment variable."
  assertEquals "$( buildCompletePath "~/$_homeRelativePath" )" "$HOME/$_homeRelativePath" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  # Very important to switch off this mode to keep on testing others features.
  MODE_CHECK_CONFIG=0

  # checkAndFormatPath Tests.
  info "Checking checkAndFormatPath function."
  # N.B.: at end, use a wildcard instead of the ending 'ir' part.
  _pathsToFormatBefore="$_subPathDir:~/$_homeRelativePath:${_subPathDir/ir/}*"
  _pathsToFormatAfter="$_checkPathRootDir/$_subPathDir:$HOME/$_homeRelativePath:$_checkPathRootDir/$_subPathDir"
  assertEquals "$( checkAndFormatPath "$_pathsToFormatBefore" "$_checkPathRootDir" )" "$_pathsToFormatAfter" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  # Very important to switch off this mode to keep on testing others features.
  MODE_CHECK_CONFIG=0

  exitingTests "checkPath"
}

# Configuration file feature Tests.
testConfigurationFileFeature() {
  local _configKey="my.config.key"
  local _configValue="my Value"
  local _configFile="$DEFAULT_TMP_DIR/localConfigurationFile.conf"

  enteringTests "config"

  info "A configuration key '$CONFIG_NOT_FOUND' should happen."

  # To avoid error when configuration key is not found, switch on this mode.
  MODE_CHECK_CONFIG=1

  # No configuration file defined, it should not be found.
  checkAndSetConfig "$_configKey" "$CONFIG_TYPE_OPTION"
  assertEquals "$LAST_READ_CONFIG" "$CONFIG_NOT_FOUND" || fail "Configuration feature is broken" $ERROR_TEST_FAILURE

  # TODO: check all other kind of $CONFIG_TYPE_XX

  # Create a configuration file.
  info "Creating the temporary configuration file '$_configFile', and configuration key should then be found."
cat > $_configFile <<EOF
$_configKey="$_configValue"
EOF

  CONFIG_FILE="$_configFile"
  checkAndSetConfig "$_configKey" "$CONFIG_TYPE_OPTION"
  info "$LAST_READ_CONFIG"
  assertEquals "$LAST_READ_CONFIG" "$_configValue" || fail "Configuration feature is broken" $ERROR_TEST_FAILURE

  # Very important to switch off this mode to keep on testing others features.
  MODE_CHECK_CONFIG=0

  exitingTests "config"
}

# Lines feature Tests.
testLinesFeature() {
  local _fileToCheck _fromLine _toLine _result
  _fileToCheck="$0"
  _fromLine=4
  _toLine=8

  enteringTests "lines"

  # TODO: creates a dedicated test file, and ensures the result ... + test all limit cases
  info "Getting lines of file '$_fileToCheck', from line '$_fromLine'"
  _result=$( getLastLinesFromN "$_fileToCheck" "$_fromLine" ) || fail "Lines feature is broken" $ERROR_TEST_FAILURE

  info "Getting lines of file '$_fileToCheck', from line '$_fromLine', to line '$_toLine'"
  _result=$( getLinesFromNToP "$_fileToCheck" "$_fromLine" "$_toLine" ) || fail "Lines feature is broken" $ERROR_TEST_FAILURE
  [ "$( echo "$_result" |wc -l )" -ne $((_toLine - _fromLine + 1)) ] && fail "Lines feature is broken" $ERROR_TEST_FAILURE

  exitingTests "lines"
}

# PID file feature Tests, without the Daemon layer which is tested elsewhere.
testPidFileFeature() {
  local _pidFile _processName
  enteringTests "pidFiles"

  _pidFile="$DEFAULT_PID_DIR/testPidFileFeature.pid"
  _processName="testPidFileFeature"

  # Limit tests, on not existing PID file.
  rm -f "$_pidFile"
  info "deletePIDFile on not existing file, must NOT fail"
  deletePIDFile "$_pidFile" || fail "PID files feature is broken" $ERROR_TEST_FAILURE

  info "getPIDFromFile with a not existing file, must produce an ERROR"
  getPIDFromFile "$_pidFile" && fail "PID files feature is broken" $ERROR_TEST_FAILURE

  info "getProcessNameFromFile with a not existing file, must produce an ERROR"
  getProcessNameFromFile "$_pidFile" && fail "PID files feature is broken" $ERROR_TEST_FAILURE

  info "isRunningProcess with a not existing file, must produce an ERROR"
  isRunningProcess "$_pidFile" "$0" && fail "PID files feature is broken" $ERROR_TEST_FAILURE

  # Normal situation.
  info "Create properly a PID file for this process"
  writePIDFile "$_pidFile" "$0" || fail "PID files feature is broken" $ERROR_TEST_FAILURE
  info "Trying to write in the existing PID file, must produce an ERROR"
  writePIDFile "$_pidFile" "$0" && fail "PID files feature is broken" $ERROR_TEST_FAILURE

  info "Check if system consider this process as still running"
  isRunningProcess "$_pidFile" "$0" || fail "PID files feature is broken" $ERROR_TEST_FAILURE

  info "Delete the PID file"
  deletePIDFile "$_pidFile" || fail "PID files feature is broken" $ERROR_TEST_FAILURE

  # TODO: test checkAllProcessFromPIDFiles

  exitingTests "pidFiles"
}

# Tests Deaemon feature.
testDaemonFeature() {
  local _pidFile _daemonPath _daemonName _daemonCompletePath
  local _failureErrorMessage="Daemon feature is broken"

  enteringTests "daemon"

  export PID_DIR="$DEFAULT_PID_DIR/testDaemonFeature/_pids"
  _daemonDirPath="$DEFAULT_TMP_DIR/testDaemonFeature"
  _daemonName="myDaemonTest.sh"
  _daemonCompletePath="$_daemonDirPath/$_daemonName"

  # Environment creation.
  updateStructure "$_daemonDirPath" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  rm -f "$_daemonCompletePath" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  cp "$daemonSample" "$_daemonCompletePath" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  chmod +x "$_daemonCompletePath" || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking the status of the Daemon ... expected result: NOT running"
  "$_daemonCompletePath" -T || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Requesting to stop the Daemon ... (warning can occur because of the process killing) expected result: NOT running"
  "$_daemonCompletePath" -K || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Starting the Daemon ..."
  "$_daemonCompletePath" -S || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE
  sleep 2

  info "Checking the status of the Daemon ... expected result: running"
  "$_daemonCompletePath" -T || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Requesting to stop the Daemon ... expected result: NOT running"
  "$_daemonCompletePath" -K || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  info "Checking the status of the Daemon ... expected result: NOT running"
  "$_daemonCompletePath" -T || fail "$_failureErrorMessage" $ERROR_TEST_FAILURE

  unset PID_DIR
  exitingTests "daemon"
}

# Triggers shUnit 2.
. "$currentDir/shunit2/shunit2"
