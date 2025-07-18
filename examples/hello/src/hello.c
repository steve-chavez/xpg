#include "pg_prelude.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(hello);
Datum hello(PG_FUNCTION_ARGS){
  text *input = PG_GETARG_TEXT_PP(0);

  StringInfoData buf;
  initStringInfo(&buf);

  appendStringInfoString(&buf, "hello ");
  appendBinaryStringInfo(&buf, VARDATA_ANY(input), VARSIZE_ANY_EXHDR(input));

  PG_RETURN_TEXT_P(cstring_to_text_with_len(buf.data, buf.len));
}
