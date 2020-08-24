%{
#include "tw_v2_parser.hpp"
#include "stdint.h"

#define MAKE_STR()          do { yylval -> s . p = yytext; yylval -> s . n = yyleng; yylval -> s . escaped = false; } while(false)

%}

%option noyywrap yylineno
%option reentrant bison-bridge
%option prefix="tw_"
%option stack
%option debug

IPV4SEG     (25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])
IPV4ADDR    ({IPV4SEG}\.){3,3}{IPV4SEG}

IPV6SEG     [0-9a-fA-F]{1,4}
IPV6_1      ({IPV6SEG}:){7,7}{IPV6SEG}
IPV6_2      ({IPV6SEG}:){1,7}:
IPV6_3      ({IPV6SEG}:){1,6}:{IPV6SEG}
IPV6_4      ({IPV6SEG}:){1,5}(:{IPV6SEG}){1,2}
IPV6_5      ({IPV6SEG}:){1,4}(:{IPV6SEG}){1,3}
IPV6_6      ({IPV6SEG}:){1,3}(:{IPV6SEG}){1,4}
IPV6_7      ({IPV6SEG}:){1,2}(:{IPV6SEG}){1,5}
IPV6_8      {IPV6SEG}:((:{IPV6SEG}){1,6})
IPV6_9      :((:{IPV6SEG}){1,7}|:)
IPV6_10     fe80:(:{IPV6SEG}){0,4}%[0-9a-zA-Z]{1,}
IPV6_11     ::(ffff(:0{1,4}){0,1}:){0,1}{IPV4ADDR}
IPV6_12     ({IPV6SEG}:){1,4}:{IPV4ADDR}
IPV6ADDR   {IPV6_1}|{IPV6_2}|{IPV6_3}|{IPV6_4}|{IPV6_5}|{IPV6_6}|{IPV6_7}|{IPV6_8}|{IPV6_9}|{IPV6_10}|{IPV6_11}|{IPV6_12}

NUMCHAR     [0-9]
NUM         {NUMCHAR}+
NUM2        {NUMCHAR}{2}
NUM4        {NUMCHAR}{4}
NUM6        {NUMCHAR}{6}

ALPHACAP    [A-Z]
ALPHACAP2   {ALPHACAP}{1,2}
HEXCHAR     [0-9A-F]
SLASH       "/"
DASH        "-"
COLON       ":"
DOT         "."

SPACE       " "
TAB         "\t"
SEP         ({SPACE}|{TAB})+

ID1         {NUM}{SLASH}{NUM}{SLASH}{NUM}{SLASH}{ALPHACAP2}
ID2         {HEXCHAR}+
ID3         {NUM}{SLASH}{NUM}

TIME        {NUM4}{DASH}{NUM2}{DASH}{NUM2}T{NUM2}{COLON}{NUM2}{COLON}{NUM2}{DOT}{NUM6}

SERVER      "traceweb"{NUM2}

IPADDR      {IPV4ADDR}|{IPV6ADDR}|"UNK_CLIENT"

SID         ({ID2}"_"{NUM4}"SID")|"UNK_SESSION"

SERVICE     [a-z_]+

EVENT       [a-zA-Z_\-:]+

MSG         .+

%x TW_ID1 TW_ID2 TW_ID3 TW_TIME TW_SERVER TW_IPADDR TW_SID TW_SERVICE TW_EVENT TW_MSG

%%

{SEP}               { MAKE_STR(); return SEP; }

<TW_ID1>{ID1}       { MAKE_STR(); yy_pop_state( yyscanner ); return ID1; }
<TW_ID1>.           { fprintf(stderr, "Unexpected character '%c' (%x) in ID1\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_ID2>{ID2}       { MAKE_STR(); yy_pop_state( yyscanner ); return ID2; }
<TW_ID2>.           { fprintf(stderr, "Unexpected character '%c' (%x) in ID2\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_ID3>{ID3}       { MAKE_STR(); yy_pop_state( yyscanner ); return ID3; }
<TW_ID2>.           { fprintf(stderr, "Unexpected character '%c' (%x) in ID3\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_TIME>{TIME}     { MAKE_STR(); yy_pop_state( yyscanner ); return TIME; }
<TW_TIME>.          { fprintf(stderr, "Unexpected character '%c' (%x) in TIME\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_SERVER>{SERVER} { MAKE_STR(); yy_pop_state( yyscanner ); return SERVER; }
<TW_SERVER>.        { fprintf(stderr, "Unexpected character '%c' (%x) in SERVER\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_IPADDR>{IPADDR} { MAKE_STR(); yy_pop_state( yyscanner ); return IPADDR; }
<TW_IPADDR>.        { fprintf(stderr, "Unexpected character '%c' (%x) in IPADDR\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_SID>{SID}       { MAKE_STR(); yy_pop_state( yyscanner ); return SID; }
<TW_SID>.           { fprintf(stderr, "Unexpected character '%c' (%x) in SID\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_SERVICE>{SERVICE}   { MAKE_STR(); yy_pop_state( yyscanner ); return SERVICE; }
<TW_SERVICE>.           { fprintf(stderr, "Unexpected character '%c' (%x) in SERVICE\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_EVENT>{EVENT}   { MAKE_STR(); yy_pop_state( yyscanner ); return EVENT; }
<TW_EVENT>.         { fprintf(stderr, "Unexpected character '%c' (%x) in EVENT\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

<TW_MSG>{MSG}       { MAKE_STR(); yy_pop_state( yyscanner ); return MSG; }

.                   { fprintf(stderr, "Unexpected character '%c' (%x)\n", yytext[0], yytext[0]); return UNRECOGNIZED; }

%%

YY_BUFFER_STATE tw_scan_reset( const char * input, yyscan_t yyscanner )
{
    YY_BUFFER_STATE ret = tw__scan_string( input, yyscanner );
    struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;    
    yyg -> yyextra_r = (void*)input;
    BEGIN( INITIAL );
    return ret;
}

void tw_get_scanner_input( yyscan_t yyscanner, t_str & str )
{
    struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;    
    const char * input = (const char*) ( yyg -> yyextra_r );
    str . p = input;
    str . n = strlen( input ); // looks wasteful but only happens when we report errors 
}

void tw_start_ID1( yyscan_t yyscanner )
{
    yy_push_state( TW_ID1, yyscanner ); 
}

void tw_start_ID2( yyscan_t yyscanner )
{
    yy_push_state( TW_ID2, yyscanner ); 
}

void tw_start_ID3( yyscan_t yyscanner )
{
    yy_push_state( TW_ID3, yyscanner ); 
}

void tw_start_TIME( yyscan_t yyscanner )
{
    yy_push_state( TW_TIME, yyscanner ); 
}

void tw_start_SERVER( yyscan_t yyscanner )
{
    yy_push_state( TW_SERVER, yyscanner ); 
}

void tw_start_IPADDR( yyscan_t yyscanner )
{
    yy_push_state( TW_IPADDR, yyscanner ); 
}

void tw_start_SID( yyscan_t yyscanner )
{
    yy_push_state( TW_SID, yyscanner ); 
}

void tw_start_SERVICE( yyscan_t yyscanner )
{
    yy_push_state( TW_SERVICE, yyscanner ); 
}

void tw_start_EVENT( yyscan_t yyscanner )
{
    yy_push_state( TW_EVENT, yyscanner ); 
}

void tw_start_MSG( yyscan_t yyscanner )
{
    yy_push_state( TW_MSG, yyscanner ); 
}

void tw_pop_state( yyscan_t yyscanner )
{
    yy_pop_state( yyscanner ); 
}