#include <gtest/gtest.h>

#include <string>

#include "url_parser.hpp"
#include "url_scanner.hpp"

using namespace std;

TEST ( TestFlex, InitDestroy )
{
    yyscan_t sc;
    ASSERT_EQ( 0, url_lex_init( &sc ) );
    ASSERT_EQ( 0, url_lex_destroy( sc ) );
}

class URL_TestFlexFixture : public ::testing::Test
{
public:
    virtual void SetUp()
    {
        url_lex_init( &sc );
    }

    virtual void TearDown()
    {
        url_lex_destroy( sc );
    }

    int StartScan( const char * input, size_t size )
    {
        url__scan_bytes( input, size, sc );
        return url_lex( & token, sc );
    }

    int StartScan( const char * input )
    {
        return StartScan( input, strlen( input ) );
    }

    int NextTokenType()
    {
        return url_lex( & token, sc );
    }

    string TokenValue() const { return string( token . str . p, token . str . n ); }

    yyscan_t sc;
    YYSTYPE token;
};

TEST_F ( URL_TestFlexFixture, EndOfFile )       { ASSERT_EQ( 0,     StartScan( "" ) ); }
TEST_F ( URL_TestFlexFixture, Accession6 )      { ASSERT_EQ( ACCESSION, StartScan( "SRR123456" ) ); ASSERT_EQ( "SRR123456", TokenValue() ); }
TEST_F ( URL_TestFlexFixture, Accession7 )      { ASSERT_EQ( ACCESSION, StartScan( "DRR1234567" ) ); ASSERT_EQ( "DRR1234567", TokenValue() ); }

TEST_F ( URL_TestFlexFixture, Slash1 )          { ASSERT_EQ( SLASH,     StartScan( "/" ) ); }
TEST_F ( URL_TestFlexFixture, Slash2 )          { ASSERT_EQ( SLASH,     StartScan( "%2F" ) ); }

TEST_F ( URL_TestFlexFixture, PathStr )         { ASSERT_EQ( PATHSTR,   StartScan( "abc&12=34" ) ); ASSERT_EQ( "abc&12=34", TokenValue() ); }

TEST_F ( URL_TestFlexFixture, Percent )         { ASSERT_EQ( PERCENT,     StartScan( "%" ) ); }
TEST_F ( URL_TestFlexFixture, PathStrWithPct )
{
    ASSERT_EQ( PATHSTR,   StartScan( "a%c/12=34" ) );
    ASSERT_EQ( "a", TokenValue() );
    ASSERT_EQ( PERCENT, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "c", TokenValue() );
}
TEST_F ( URL_TestFlexFixture, PathStrWithURLEncoding )
{
    ASSERT_EQ( PATHSTR,   StartScan( "a%1f/12=34" ) );
    ASSERT_EQ( "a%1f", TokenValue() );
}

TEST_F ( URL_TestFlexFixture, PathDot )
{
    ASSERT_EQ( DOT,   StartScan( ".txt" ) );
    ASSERT_EQ( EXTSTR, NextTokenType() );
    ASSERT_EQ( "txt", TokenValue() );
}

TEST_F ( URL_TestFlexFixture, PathTokens )
{
    ASSERT_EQ( SLASH, StartScan( "/part1/part2/leaf.txt/a" ) );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "part1", TokenValue() );
    ASSERT_EQ( SLASH, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "part2", TokenValue() );
    ASSERT_EQ( SLASH, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "leaf", TokenValue() );
    ASSERT_EQ( DOT,   NextTokenType() );
    ASSERT_EQ( EXTSTR, NextTokenType() );
    ASSERT_EQ( "txt", TokenValue() );
    ASSERT_EQ( SLASH, NextTokenType() ); // scanner is back to the default state
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "a", TokenValue() );
}

TEST_F ( URL_TestFlexFixture, Qmark )           { ASSERT_EQ( QMARK,     StartScan( "?" ) ); }
TEST_F ( URL_TestFlexFixture, QSeparator1 )     { ASSERT_EQ( QMARK,     StartScan( "?&" ) ); ASSERT_EQ( QUERY_SEP, NextTokenType() ); }
TEST_F ( URL_TestFlexFixture, QSeparator2 )     { ASSERT_EQ( QMARK,     StartScan( "?;" ) ); ASSERT_EQ( QUERY_SEP, NextTokenType() ); }
TEST_F ( URL_TestFlexFixture, Equal )           { ASSERT_EQ( QMARK,     StartScan( "?=" ) ); ASSERT_EQ( EQUAL, NextTokenType() ); }

TEST_F ( URL_TestFlexFixture, QToken1 )
{
    ASSERT_EQ( QMARK, StartScan( "?a1=b" ) );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "a1", TokenValue() );
    ASSERT_EQ( EQUAL, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "b", TokenValue() );
}

TEST_F ( URL_TestFlexFixture, QToken2 )
{
    ASSERT_EQ( QMARK, StartScan( "?a1=b&bb=t1" ) );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "a1", TokenValue() );
    ASSERT_EQ( EQUAL, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "b", TokenValue() );
    ASSERT_EQ( QUERY_SEP, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "bb", TokenValue() );
    ASSERT_EQ( EQUAL, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "t1", TokenValue() );
}

TEST_F ( URL_TestFlexFixture, QEncodedValues )
{   // in the query, recognize %2f and %2F as s separte token (SLASH),
    // other encodings as regular characters
    ASSERT_EQ( QMARK, StartScan( "?a1=b%cd%g&e=f%2fgh" ) );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "a1", TokenValue() );
    ASSERT_EQ( EQUAL, NextTokenType() );

    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "b%cd", TokenValue() );  // cd is hex!
    ASSERT_EQ( PERCENT, NextTokenType() );// g is not hex!
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "g", TokenValue() );

    ASSERT_EQ( QUERY_SEP, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "e", TokenValue() );
    ASSERT_EQ( EQUAL, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "f", TokenValue() );
    ASSERT_EQ( SLASH, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "gh", TokenValue() );
}

TEST_F ( URL_TestFlexFixture, QMultipleQM )
{
    ASSERT_EQ( QMARK, StartScan( "?a1=?b" ) );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "a1", TokenValue() );
    ASSERT_EQ( EQUAL, NextTokenType() );
    ASSERT_EQ( PATHSTR, NextTokenType() );
    ASSERT_EQ( "?b", TokenValue() );
}

// TEST_F ( URL_TestFlexFixture, QToken3 )
// {
//     ASSERT_EQ( QMARK, StartScan( "?a1=SRR000123%2FSRR000456" ) );
//     ASSERT_EQ( QUERY_TOKEN, NextTokenType() );
//     ASSERT_EQ( "a1", TokenValue() );
//     ASSERT_EQ( EQUAL, NextTokenType() );
//     ASSERT_EQ( ACCESSION, NextTokenType() );
//     ASSERT_EQ( "SRR000123", TokenValue() );
//     ASSERT_EQ( QUERY_TOKEN, NextTokenType() );
//     ASSERT_EQ( "%2F", TokenValue() );
//     ASSERT_EQ( ACCESSION, NextTokenType() );
//     ASSERT_EQ( "SRR000456", TokenValue() );
// }

TEST_F ( URL_TestFlexFixture, Hash1 )           { ASSERT_EQ( HASH,      StartScan( "#" ) ); }
TEST_F ( URL_TestFlexFixture, Hash2 )           { ASSERT_EQ( QMARK,     StartScan( "?#" ) ); ASSERT_EQ( HASH, NextTokenType() ); }

TEST_F ( URL_TestFlexFixture, Fragments1 )
{
    ASSERT_EQ( HASH, StartScan( "#something" ) );
    ASSERT_EQ( FRAGMENT_TOKEN, NextTokenType() );
    ASSERT_EQ( "something", TokenValue() );
}

TEST_F ( URL_TestFlexFixture, Fragments2 )
{
    ASSERT_EQ( QMARK, StartScan( "?#something" ) );
    ASSERT_EQ( HASH, NextTokenType() );
    ASSERT_EQ( FRAGMENT_TOKEN, NextTokenType() );
    ASSERT_EQ( "something", TokenValue() );
}
