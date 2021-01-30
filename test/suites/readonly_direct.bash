SUITE_readonly_direct_PROBE() {
    mkdir dir
    if $HOST_OS_WINDOWS; then
        icacls dir //deny "Everyone:(OI)(CI)(WD,AD,WEA,WA)" //T >/dev/null
    else
        chmod a-w dir
    fi
    if touch dir/probe 2>/dev/null; then
        echo "File system doesn't support read-only mode"
    fi
    rm -fr dir
}

SUITE_readonly_direct_SETUP() {
    unset CCACHE_NODIRECT

    generate_code 1 test.c
}

SUITE_readonly_direct() {
    # -------------------------------------------------------------------------
    TEST "Direct hit"

    $CCACHE_COMPILE -c test.c -o test.o
    expect_stat 'cache hit (direct)' 0
    expect_stat 'cache hit (preprocessed)' 0
    expect_stat 'cache miss' 1

    CCACHE_READONLY_DIRECT=1 $CCACHE_COMPILE -c test.c -o test.o
    expect_stat 'cache hit (direct)' 1
    expect_stat 'cache hit (preprocessed)' 0
    expect_stat 'cache miss' 1

    # -------------------------------------------------------------------------
    TEST "Direct miss doesn't lead to preprocessed hit"

    $CCACHE_COMPILE -c test.c -o test.o
    expect_stat 'cache hit (direct)' 0
    expect_stat 'cache hit (preprocessed)' 0
    expect_stat 'cache miss' 1

    CCACHE_READONLY_DIRECT=1 $CCACHE_COMPILE -DFOO -c test.c -o test.o
    expect_stat 'cache hit (direct)' 0
    expect_stat 'cache hit (preprocessed)' 0
    expect_stat 'cache miss' 2
}
