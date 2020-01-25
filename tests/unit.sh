#!/usr/bin/env sh
# Unit tests for the ok.sh script.

SCRIPT="../ok.sh"
JQ="${OK_SH_JQ_BIN:-jq}"
JQ_V="$(jq --version 2>&1 | awk '{ print $3 }')"

_main() {
    local cmd ret

    cmd="$1" && shift
    "$cmd" "$@"
    ret=$?

    [ $ret -eq 0 ] || printf 'Fail: %s\n' "$cmd" 1>&2
    exit $ret
}

test_format_json() {
    # Test output without filtering through jq.

    local output
    local is_fail=0

    $SCRIPT -j _format_json foo=Foo bar=123 baz=true qux=Qux=Qux quux='Multi-line
string' quuz=\'5.20170918\' corge="$(${SCRIPT} _format_json grault=Grault)" \
    garply="$(${SCRIPT} _format_json -a waldo true 3)" | {
        read -r output

        printf '%s\n' "$output" | grep -q -E '^\{' || {
            printf 'JSON does not start with a { char.\n'; is_fail=1 ;}
        printf '%s\n' "$output" | grep -q -E '}$' || {
            printf 'JSON does not end with a } char.\n'; is_fail=1 ;}
        printf '%s\n' "$output" | grep -q -E '"foo": "Foo"' || {
            printf 'JSON does not contain "foo": "Foo" text.\n'; is_fail=1 ;}
        printf '%s\n' "$output" | grep -q -E '"Multi-line\\nstring"' || {
            printf 'JSON does not have properly formatted multiline string.\n'; is_fail=1 ;}
        printf '%s\n' "$output" | grep -q -E '"5\.20170918"' || {
            printf 'JSON does not have properly quoted numbers.\n'; is_fail=1 ;}
        printf '%s\n' "$output" | grep -q -E '"Grault"' || {
            printf 'JSON does not have properly nested structure\n'; is_fail=1 ;}
        printf '%s\n' "$output" | grep -q -E '"garply": \["' || {
            printf 'JSON does not have properly nested arrays\n'; is_fail=1 ;}

        if [ "$is_fail" -ne 1 ] ; then
            return 0
        else
            printf 'Unexpected JSON output: `%s`\n' "$output"
            return 1
        fi
    }
}

test_format_urlencode() {
    # _format_urlencode 

    local output num_params
    local is_fail=0

    $SCRIPT _format_urlencode foo='Foo Foo' bar='<Bar>&/Bar/' | {
        read -r output

        printf '%s\n' "$output" | grep -q -E 'foo=Foo%20Foo' || {
            printf 'Urlencoded output malformed foo section.\n'; is_fail=1 ;}

        printf '%s\n' "$output" | grep -q -E 'bar=%3CBar%3E%26%2FBar%2F' || {
            printf 'Urlencoded output malformed bar section.\n'; is_fail=1 ;}

        num_params="$(printf '%s\n' "$output" | awk -F'&' '{ print NF }')"
        if [ "$num_params" -ne 2 ] ; then
            printf 'Urlencoded output has %s sections; expected 2.\n'\
                "$num_params"
            is_fail=1
        fi

        if [ "$is_fail" -ne 1 ] ; then
            return 0
        else
            printf 'Unexpected urlencoded output\n' "$output"
            return 1
        fi
    }
}

test_format_json_jq() {
    # Test output after filtering through jq.

    local output keys vals expected_out

    $SCRIPT _format_json foo=Foo bar=123 baz=true qux=Qux=Qux quux='Multi-line
string' | {
        read -r output

        keys=$(printf '%s\n' "$output" | jq -r -c 'keys | .[]' | sort | paste -s -d',' -)
        vals=$(printf '%s\n' "$output" | jq -r -c '.[]' | sort | paste -s -d',' -)

        if [ 'bar,baz,foo,quux,qux' = "$keys" ] && [ '123,Foo,Multi-line,Qux=Qux,string,true' = "$vals" ] ; then
            return 0
        else
            printf 'Expected output does not match output: `%s` != `%s`\n' \
                "$expected_out" "$output"
            return 1
        fi
    }
}

test_filter_json_args() {
    local json out
    json='["foo", "bar", true, {"qux": "Qux"}]'

    printf '%s\n' "$json" | $SCRIPT _filter_json 'length' | {
        read -r out

        if [ 4 -eq "$out" ] ; then
            return 0
        else
            printf 'Expected output does not match output: `%s` != `%s`\n' \
                "$expected_out" "$out"
            return 1
        fi
    }
}

test_filter_json_pipe() {
    # Test for issue #16.

    local out
    local json='[{"name": "Foo"}]'
    local expected_out='Foo'

    printf '%s\n' "$json" | $SCRIPT _filter_json '.[] | .["name"]' | {
        read -r out

        if [ "$expected_out" = "$out" ] ; then
            return 0
        else
            printf 'Expected output does not match output: `%s` != `%s`\n' \
                "$expected_out" "$out"
            return 1
        fi
    }
}

test_response_headers() {
    # Test that process response outputs headers in deterministic order.

    local baz bar foo

    printf 'HTTP/1.1 200 OK
Server: example.com
Foo: Foo!
Bar: Bar!
Baz: Baz!

Hi\n' | $SCRIPT _response Baz Bad Foo | {
        read -r baz
        read -r bar     # Ensure unfound items are blank.
        read -r foo

        ret=0
        [ "$baz" = 'Baz!' ] || { ret=1; printf '`Baz!` != `%s`\n' "$baz"; }
        [ "$bar" = '' ] || { ret=1; printf '`` != `%s`\n' "$bar"; }
        [ "$foo" = 'Foo!' ] || { ret=1; printf '`Foo!` != `%s`\n' "$foo"; }

        return $ret
    }
}

test_response_headers_100_continue() {
    # Test that process response 100 Continue is handled correctly.

    local baz bar foo

    header_100='HTTP/1.1 100 Continue\r\n\r\n'
    header_200='HTTP/1.1 200 OK\r\n'
    header_key_value='Server: example.com\r\nFoo: Foo!\r\nBar: Bar!\r\nBaz: Baz!\r\n\r\nHi\n'
    printf "${header_100}${header_100}${header_200}${header_key_value}" | $SCRIPT _response Baz Bad Foo | {
        read -r baz
        read -r bar     # Ensure unfound items are blank.
        read -r foo

        ret=0
        [ "$baz" = 'Baz!' ] || { ret=1; printf '`Baz!` != `%s`\n' "$baz"; }
        [ "$bar" = '' ] || { ret=1; printf '`` != `%s`\n' "$bar"; }
        [ "$foo" = 'Foo!' ] || { ret=1; printf '`Foo!` != `%s`\n' "$foo"; }

        return $ret
    }
}

_main "$@"
