SUITE_readonly_PROBE() {
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

SUITE_readonly_SETUP() {
    generate_code 1 test.c
    generate_code 2 test2.c
}

SUITE_readonly() {
    # -------------------------------------------------------------------------
    TEST "Cache hit"

    # Cache a compilation.
    $CCACHE_COMPILE -c test.c
    expect_stat 'cache hit (preprocessed)' 0
    expect_stat 'cache miss' 1
    rm test.o

    # Make the cache read-only.
    if $HOST_OS_WINDOWS; then
        icacls $CCACHE_DIR //deny "Everyone:(OI)(CI)(WD,AD,WEA,WA)" //T >/dev/null
    else
        chmod -R a-w $CCACHE_DIR
    fi

    # Check that read-only mode finds the cached result.
    CCACHE_READONLY=1 CCACHE_TEMPDIR=/tmp CCACHE_PREFIX=false $CCACHE_COMPILE -c test.c
    status1=$?

    # Check that fallback to the real compiler works for a cache miss.
    CCACHE_READONLY=1 CCACHE_TEMPDIR=/tmp $CCACHE_COMPILE -c test2.c
    status2=$?

    # Leave test dir in a nice state after test failure.
    if $HOST_OS_WINDOWS; then
        icacls $CCACHE_DIR //reset //T >/dev/null
    else
        chmod -R +w $CCACHE_DIR
    fi

    if [ $status1 -ne 0 ]; then
        test_failed "Failure when compiling test.c read-only"
    fi
    if [ $status2 -ne 0 ]; then
        test_failed "Failure when compiling test2.c read-only"
    fi
    expect_exists test.o
    expect_exists test2.o

    # -------------------------------------------------------------------------
    TEST "Cache miss"

    # Check that read-only mode doesn't try to store new results.
    CCACHE_READONLY=1 CCACHE_TEMPDIR=/tmp $CCACHE_COMPILE -c test.c
    if [ $? -ne 0 ]; then
        test_failed "Failure when compiling test2.c read-only"
    fi
    expect_stat 'cache hit (preprocessed)' 0
    expect_stat 'cache miss' 1
    expect_stat 'files in cache' 0

    # -------------------------------------------------------------------------
    # Check that read-only mode and direct mode work together.
    TEST "Cache hit, direct"

    # Cache a compilation.
    $CCACHE_COMPILE -c test.c
    expect_stat 'cache hit (preprocessed)' 0
    expect_stat 'cache miss' 1
    rm test.o

    # Make the cache read-only.
    if $HOST_OS_WINDOWS; then
        icacls $CCACHE_DIR //deny "Everyone:(OI)(CI)(WD,AD,WEA,WA)" //T >/dev/null
    else
        chmod -R a-w $CCACHE_DIR
    fi

    # Direct mode should work:
    files_before=`find $CCACHE_DIR -type f | wc -l`
    CCACHE_DIRECT=1 CCACHE_READONLY=1 CCACHE_TEMPDIR=/tmp $CCACHE_COMPILE -c test.c
    files_after=`find $CCACHE_DIR -type f | wc -l`

    # Leave test dir in a nice state after test failure.
    if $HOST_OS_WINDOWS; then
        icacls $CCACHE_DIR //reset //T >/dev/null
    else
        chmod -R +w $CCACHE_DIR
    fi

    if [ $? -ne 0 ]; then
        test_failed "Failure when compiling test.c read-only"
    fi
    if [ $files_after -ne $files_before ]; then
        test_failed "Read-only mode + direct mode stored files in the cache"
    fi
}
