%define api.pure full
%lex-param { void * scanner }
%parse-param { void * scanner }{ NCBI::Logging::AWS_LogLines * lib }

%define parse.trace
%define parse.error verbose

%name-prefix "aws_"

%{
#define YYDEBUG 1

#include <stdint.h>

#include "log_lines.hpp"
#include "aws_parser.hpp"
#include "aws_scanner.hpp"
#include "helper.hpp"

using namespace std;
using namespace NCBI::Logging;

void aws_error( yyscan_t locp, NCBI::Logging::AWS_LogLines * lib, const char* msg );

%}

%code requires
{
#include "types.h"
#include "log_lines.hpp"

extern void aws_get_scanner_input( void * yyscanner, t_str & str );
extern void aws_start_URL( void * yyscanner );
//extern void aws_stop_URL( void * yyscanner );

using namespace NCBI::Logging;
}

%union
{
    t_str s;
    t_timepoint tp;
    t_request req;
}

%token<s> STR STR1 MONTH IPV4 IPV6 METHOD VERS QSTR DASH I64 AMPERSAND EQUAL PERCENT SLASH QMARK
%token<s> PATHSTR PATHEXT ACCESSION SPACE 
%token COLON QUOTE OB CB 
%token UNRECOGNIZED

%type<tp> time
%type<s> ip referer agent agent_list method qstr_list dash string_or_dash
%type<s> aws_owner aws_bucket aws_requester aws_request_id aws_operation aws_error
%type<s> aws_version_id aws_host_id aws_sig aws_cipher aws_auth aws_host_hdr aws_tls_vers
%type<s> result_code aws_bytes_sent aws_obj_size aws_total_time aws_turnaround_time empty_or_not
%type<req> request aws_key url_token url_list url key_token aws_quoted_key

%start line

%%

line
    : log_aws       { YYACCEPT; }
    | log_aws_err   { YYACCEPT; }
    ;

log_aws
    : aws_owner SPACE
      aws_bucket SPACE
      time SPACE
      ip SPACE
      aws_requester SPACE
      aws_request_id SPACE
      aws_operation SPACE
      { aws_start_URL( scanner ); } aws_quoted_key SPACE
      request SPACE
      result_code SPACE
      aws_error SPACE
      aws_bytes_sent SPACE
      aws_obj_size SPACE
      aws_total_time SPACE
      aws_turnaround_time SPACE
      referer SPACE
      agent SPACE
      aws_version_id SPACE
      aws_host_id SPACE
      aws_sig SPACE
      aws_cipher SPACE
      aws_auth SPACE
      aws_host_hdr SPACE
      aws_tls_vers 
      empty_or_not
    {
        if ( $49 . n > 0 )
        {   // there are extra tokens present, which is likely to mean that thye whole
            // structure would be populated incorrectly
            YYABORT; 
        }

        LogAWSEvent ev;
        ev . owner = $1;
        ev . bucket = $3;
        ev . time = $5;
        ev . ip = $7;
        ev . requester = $9;
        ev . request_id = $11;
        ev . operation = $13;

        ev . request = $18; // this has to happen before we use the key-decomposition
        // combine data from aws_key and request
        if ( $16 . path . n == 1 && $16 . path . p[ 0 ] == '-' )
        {
            EMPTY_TSTR( ev . key );
        }
        else if ( $16 . path . n == 3 && $16 . path . p[ 0 ] == '\"' && $16 . path . p[ 1 ] == '-' && $16 . path . p[ 2 ] == '\"' )
        {
            EMPTY_TSTR( ev . key );
        }
        else
        {
            ev . key = $16 . path;
        }
        if ( $16 . accession . n > 0 )
        {
            ev . request . accession = $16 . accession;
            ev . request . filename  = $16 . filename;
            ev . request . extension = $16 . extension;
        }

        ev . res_code           = $20;
        ev . error              = $22;
        ev . res_len            = $24;
        ev . obj_size           = $26;
        ev . total_time         = $28;
        ev . turnaround_time    = $30;
        ev . referer            = $32;
        ev . agent              = $34;
        ev . version_id         = $36;
        ev . host_id            = $38;
        ev . sig_ver            = $40;
        ev . cipher_suite       = $42;
        ev . auth_type          = $44;
        ev . host_header        = $46;
        ev . tls_version        = $48;
        
        lib -> acceptLine( ev );
    }
    ;

empty_or_not
    : %empty    { EMPTY_TSTR($$); }
    | SPACE     { $$ . n = 1; $$ . p = " "; }
    ;

dash
    : DASH                  { EMPTY_TSTR($$); }
    | QUOTE DASH QUOTE      { EMPTY_TSTR($$); }
    ;

string_or_dash
    : STR
    | STR1
    | dash
    ;

log_aws_err
    : aws_owner error
    {
        LogAWSEvent ev;
        ev . owner = $1;
        aws_get_scanner_input( scanner, ev . unparsed );
        lib -> rejectLine( ev );
    }
    ;

aws_owner : string_or_dash ;
aws_bucket : string_or_dash ;
aws_requester : string_or_dash ;
aws_request_id : string_or_dash ;
aws_operation : string_or_dash ;

key_token
    : SLASH         { InitRequest( $$ ); $$ . path = $1; }
    | EQUAL         { InitRequest( $$ ); $$ . path = $1; }
    | AMPERSAND     { InitRequest( $$ ); $$ . path = $1; }
    | QMARK         { InitRequest( $$ ); $$ . path = $1; }
    | PERCENT       { InitRequest( $$ ); $$ . path = $1; }
    | ACCESSION     { InitRequest( $$ ); $$ . path = $1; $$ . accession = $1; }
    | PATHSTR       { InitRequest( $$ ); $$ . path = $1; $$ . filename = $1; }
    | PATHEXT       { InitRequest( $$ ); $$ . path = $1; $$ . extension = $1; }
    ;

aws_key
    : key_token
        {
            $$ = $1;
            if ( $1 . accession . n > 0 )
            {
                $$ . filename  = $1 . accession;
            }
        }    
    | aws_key key_token    
        { 
            $$ . path . n += $2 . path . n;

            // clear the filename and extension after every slash - to make sure we catch only the last
            // filename and extension in case of middle segments existing
            if ( $2 . path . n == 1 && $2 . path . p[ 0 ] == '/' )
            {
                $$ . filename . n = 0;
                $$ . extension . n = 0;
            }
            else if ( $2 . accession . n > 0 )
            {
                // we will use the last non-empty accession-looking token
                $$ . accession = $2 . accession;
                $$ . filename  = $2 . accession;
            }
            else if ( $2 . filename . n > 0 )
            {
                $$ . filename  = $2 . filename;
                $$ . extension . n = 0;
            }
            else if ( $2 . extension . n > 0 )
            {
                $$ . extension = $2 . extension;
            }
        }
    ;

aws_quoted_key
    : aws_key
    | QUOTE DASH QUOTE {  InitRequest( $$ ); }
    ;

aws_error : string_or_dash ;

aws_bytes_sent
    : STR
    | dash
    ;

aws_obj_size
    : STR
    | dash
    ;

aws_total_time
    : STR
    | dash
    ;

aws_turnaround_time
    : STR
    | dash
    ;

aws_version_id : string_or_dash ;
aws_host_id : string_or_dash ;
aws_sig : string_or_dash ;
aws_cipher : string_or_dash ;
aws_auth : string_or_dash ;
aws_host_hdr : string_or_dash ;
aws_tls_vers : string_or_dash ;

ip
    : IPV4
    | IPV6
    | dash
    ;

method
    : METHOD        { $$ = $1; }
    | dash
    ;

qstr_list
    : QSTR                  { $$ = $1; }
    | qstr_list SPACE QSTR  { $$ = $1; $$.n += 1 + $3.n; $$.escaped = $1.escaped || $3.escaped; }
    ;

 /* 
    typedef enum { acc_before = 0, acc_inside, acc_after } eAccessionMode; (defined in log_lines.hpp)

        for a url_token node, set to 
            'acc_inside' if it is an ACCESSION
            'acc_after'  if it is a delimiter

        for a url_list node, describes the state of URL parsing:
            'acc_before' - no accession has been seen yet
            'acc_inside' - we are between the first accession and the following delimiter,
                            capture the filename and extension tokens
            'acc_after'  - we are past delimiter following an accession, 
                            no further action necessary
 */

url_token
    : SLASH         { InitRequest( $$ ); $$ . path = $1; }
    | EQUAL         { InitRequest( $$ ); $$ . path = $1; $$.accession_mode = acc_after; }
    | AMPERSAND     { InitRequest( $$ ); $$ . path = $1; $$.accession_mode = acc_after; }
    | QMARK         { InitRequest( $$ ); $$ . path = $1; $$.accession_mode = acc_after; }
    | PERCENT       { InitRequest( $$ ); $$ . path = $1; }
    | ACCESSION     
        { 
            InitRequest( $$ ); 
            $$ . path = $1; 
            $$ . accession = $1; 
            $$ . accession_mode = acc_inside; 
        }
    | PATHSTR       { InitRequest( $$ ); $$ . path = $1; $$ . filename = $1; }
    | PATHEXT       { InitRequest( $$ ); $$ . path = $1; $$ . extension = $1; }
    ;

 /* This is a collection of url tokens and accessions. 
    We are looking for the first accession and filename/extension that follow it.*/
url_list
    :  url_token               
        { 
            $$ = $1; 
            if ( $1 . accession_mode == acc_after )            
            {   /* a delimiter seen before an accession */
                $$ . accession_mode = acc_before;
            }
        }
    |  url_list url_token
        { 
            $$ = $1; 
            MERGE_TSTR( $$ . path, $2 . path );
            switch ( $$.accession_mode )
            {
            case acc_before:
                if ( $2.accession_mode == acc_inside )
                {
                    $$ . accession = $2 . accession;
                    $$ . accession_mode = acc_inside;
                }
                break;
            case acc_inside:
                switch ( $2 . accession_mode )
                {
                case acc_inside:
                    $$ . filename  = $2 . accession;
                    break;
                case acc_after:
                    $$ . accession_mode = acc_after;
                    break;
                default:
                    if ( $2 . filename . n > 0 )    $$ . filename  = $2 . filename;
                    if ( $2 . extension . n > 0 )   $$ . extension = $2 . extension;
                }
                break;
            }
        }
    ;

url
    : SPACE { aws_start_URL( scanner ); } url_list { $$ = $3; }
    ;

request
    : QUOTE method url SPACE VERS QUOTE
    {
        $$ = $3;
        $$.method = $2;
        $$.vers   = $5;
    }
    | QUOTE method url SPACE QUOTE
    {
        $$ = $3;
        $$.method = $2;
     }
    | QUOTE method url QUOTE
    {
        $$ = $3;
        $$.method = $2;
    }
    | QUOTE method QUOTE 
    {
        InitRequest( $$ );
        $$.method = $2;
    }
    | QUOTE { aws_start_URL( scanner ); } url_list QUOTE
    {
        $$ = $3;
    }
    | DASH { InitRequest( $$ );}
    ;

result_code
    : STR
    | dash
    ;

referer
    : QUOTE qstr_list QUOTE { $$ = $2; }
    | string_or_dash
    ;

agent_list
    : QSTR                          { $$ = $1; }
    | agent_list QSTR               { $$ = $1; $$.n += $2.n; $$.escaped = $1.escaped || $2.escaped; }
    | agent_list SPACE              { $$ = $1; $$.n += 1;    $$.escaped = $1.escaped; }    
    ;

agent
    : QUOTE agent_list QUOTE        { $$ = $2; }
    | dash
    ;

time
    : OB I64 SLASH MONTH SLASH I64 COLON I64 COLON I64 COLON I64 I64 CB
    {
        $$.day = atoi( $2.p );
        $$.month = month_int( &($4) );
        $$.year = atoi( $6.p );
        $$.hour = atoi( $8.p );
        $$.minute = atoi( $10.p );
        $$.second = atoi( $12.p );
        $$.offset = atoi( $13.p );
    } 
    | dash  { memset( &($$), 0, sizeof $$ ); }
    ;

%%

void aws_error( yyscan_t locp, NCBI::Logging::AWS_LogLines * lib, const char * msg )
{
    // intentionally left empty, we communicate errors rejected lines
}