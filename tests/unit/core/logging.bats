#!/usr/bin/env bats
# Unit tests for lib/core/logging.sh

setup() {
	load '../../test_helper/common'
	load '../../test_helper/assertions'
	setup_isolated_home
}

teardown() {
	teardown_isolated_home
}

@test "mantle_log_info writes to stderr" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		mantle_log_info 'hello world' 2>&1
	"
	assert_success
	assert_output_contains "[mantle:info]"
	assert_output_contains "hello world"
}

@test "mantle_log_warn writes to stderr" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		mantle_log_warn 'careful' 2>&1
	"
	assert_success
	assert_output_contains "[mantle:warn]"
}

@test "mantle_log_error writes to stderr" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		mantle_log_error 'something failed' 2>&1
	"
	assert_success
	assert_output_contains "[mantle:error]"
}

@test "mantle_log_success writes to stderr" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		mantle_log_success 'done' 2>&1
	"
	assert_success
	assert_output_contains "[mantle:ok]"
}

@test "mantle_log_debug is silent when MANTLE_DEBUG is unset" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		mantle_log_debug 'secret debug' 2>&1
	"
	assert_success
	assert_output_not_contains "secret debug"
}

@test "mantle_log_debug writes when MANTLE_DEBUG=1" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		MANTLE_DEBUG=1
		export MANTLE_ROOT MANTLE_DEBUG
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		mantle_log_debug 'debug message' 2>&1
	"
	assert_success
	assert_output_contains "debug message"
}

@test "logging.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/core/logging.sh"
	assert_status 64
}

@test "logging.sh is idempotent" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		printf 'ok\n'
	"
	assert_success
	assert_output_contains "ok"
}
