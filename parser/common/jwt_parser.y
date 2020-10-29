%define api.pure full
%lex-param { void * scanner }
%parse-param { void * scanner }{ NCBI::Logging::JWTReceiver * lib }

%define parse.trace
%define parse.error verbose

%name-prefix "jwt_"

%{
#define YYDEBUG 1

#include <stdint.h>
#include "jwt_parser.hpp"
#include "jwt_scanner.hpp"

using namespace std;
using namespace NCBI::Logging;

void jwt_error( yyscan_t locp, NCBI::Logging::JWTReceiver * lib, const char* msg );

const t_str EmptyTSTR = { "", 0 };

#define SET_VALUE( selector, source )   ( lib -> set( (selector), (source) ) )

%}

%code requires
{
#include "types.h"
#include "JWT_Interface.hpp"

extern void jwt_get_scanner_input( void * yyscanner, t_str & str );

using namespace NCBI::Logging;
}

%define api.value.type {t_str}

%token JWT STR

%start jwt_line

%%

jwt_line
    : str_list
    | error     { YYABORT; }
    | %empty    { }
    ;

str_token
    : JWT { lib -> setJwt( $1 ); }
    | STR
    ;

str_list
    : str_token
    | str_list str_token
    ;


%%

void jwt_error( yyscan_t locp, NCBI::Logging::JWTReceiver * lib, const char * msg )
{
    // intentionally left empty, we communicate errors rejected lines
}
