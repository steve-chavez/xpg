#include "pg_prelude.h"
#include <pthread.h>
 

static int Global;

static void *Thread1(void *x) {
  Global = 42;
  return x;
}


PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(hello);
Datum hello(PG_FUNCTION_ARGS){
  text *input = PG_GETARG_TEXT_PP(0);

  StringInfoData buf;
  initStringInfo(&buf);


  // ASAN should flag this
  if (getenv("HELLO_OOB_WRITE")) {
    char *buf2 = (char *)malloc(4);
    buf2[5] = 'A'; // Writing past the 4-byte heap buffer
    free(buf2);
  }
 
  // UBSAN should flag this
  if (getenv("HELLO_NULL_PTR_DEREF")) {
    int *i = NULL;
    printf("%d\n", *i);
  }

  // TSAN should flag this
  if (getenv("HELLO_THREAD_DATA_RACE")) {
    pthread_t t;
    pthread_create(&t, NULL, Thread1, NULL);
    Global = 43;
    pthread_join(t, NULL);
    printf("%d\n", Global);
    printf("%d\n", *((int *)Thread1(&Global)));
  }

  appendStringInfoString(&buf, "hello ");
  appendBinaryStringInfo(&buf, VARDATA_ANY(input), VARSIZE_ANY_EXHDR(input));

  PG_RETURN_TEXT_P(cstring_to_text_with_len(buf.data, buf.len));
}
