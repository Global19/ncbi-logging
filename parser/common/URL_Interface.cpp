#include "URL_Interface.hpp"

#include "url_parser.hpp"
#include "url_scanner.hpp"

#include <ncbi/json.hpp>
#include "Formatters.hpp"

extern YY_BUFFER_STATE url_scan_bytes( const char * input, size_t size, yyscan_t yyscanner );

using namespace NCBI::Logging;
using namespace std;
using namespace ncbi;


URLReceiver::URLReceiver( FormatterRef fmt )
: ReceiverInterface ( fmt )
{
}

void URLReceiver::finalize( void )
{
    setMember( "accession", t_str{ m_accession.c_str(), m_accession.size() } );
    setMember( "filename",  t_str{ m_filename.c_str(), m_filename.size() } );
    setMember( "extension", t_str{ m_extension.c_str(), m_extension.size() } );
    m_accession . clear();
    m_filename . clear();
    m_extension . clear();
}

/* -------------------------------------------------------------------------- */

URLParseBlock::URLParseBlock( URLReceiver & receiver )
: m_receiver ( receiver )
{
    url_lex_init( &m_sc );
}

URLParseBlock::~URLParseBlock()
{
    url_lex_destroy( m_sc );
}

bool
URLParseBlock::format_specific_parse( const char * line, size_t line_size )
{
    url_debug = m_debug ? 1 : 0;                // bison (is global)
    url_set_debug( m_debug ? 1 : 0, m_sc );   // flex

    YY_BUFFER_STATE bs = url_scan_bytes( line, line_size, m_sc );
    int ret = url_parse( m_sc, & m_receiver );
    url__delete_buffer( bs, m_sc );

    if ( ret != 0 )
        m_receiver . SetCategory( ReceiverInterface::cat_ugly );
    else if ( m_receiver .GetCategory() == ReceiverInterface::cat_unknown )
        m_receiver . SetCategory( ReceiverInterface::cat_good );
    return ret == 0;
}
