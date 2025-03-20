#include "pg_prelude.h"
#include "tinyexpr.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(pltinyexpr_inline_handler);
Datum pltinyexpr_inline_handler(PG_FUNCTION_ARGS)
{
	InlineCodeBlock *codeblock = (InlineCodeBlock *) DatumGetPointer(PG_GETARG_DATUM(0));
	char* src = codeblock->source_text;

	double res;
	int error_pos;

	res = te_interp(src, &error_pos);

	if (error_pos > 0)
		ereport(ERROR, errmsg("%.*s<- bad syntax here", error_pos, src));
	else
		elog(INFO, "expression result is: %lf", res);

	PG_RETURN_VOID();
}

PG_FUNCTION_INFO_V1(pltinyexpr_handler);
Datum pltinyexpr_handler(PG_FUNCTION_ARGS)
{
	Oid function_oid = fcinfo->flinfo->fn_oid;
	HeapTuple proc_tuple;
	Datum prosrc;
	char* src;
	bool is_null;
	int numargs;
	Oid* argtypes;
	char** argnames;
	char* argmodes;

	double res;
	int error_pos;

	proc_tuple = SearchSysCache(PROCOID, ObjectIdGetDatum(function_oid), 0, 0, 0);
	if (!HeapTupleIsValid(proc_tuple))
		elog(ERROR, "could not find function with oid %u", function_oid);

	prosrc = SysCacheGetAttr(PROCOID, proc_tuple, Anum_pg_proc_prosrc, &is_null);
	if(is_null)
			ereport(ERROR, errmsg("pg_proc.prosrc is NULL"));

	src = text_to_cstring(DatumGetTextPP(prosrc));

	numargs = get_func_arg_info(proc_tuple, &argtypes, &argnames, &argmodes);

	if(numargs > 0){
		te_expr* expr;
		te_variable* vars = palloc0(sizeof(te_variable) * numargs);
		double* argvalues = palloc0(sizeof(double) * numargs);

		for(int i = 0; i < numargs; i++){
			argvalues[i] = DatumGetFloat8(fcinfo->args[i].value);
			vars[i].name = argnames[i];
			vars[i].address = &(argvalues[i]);
		}

		expr = te_compile(src, vars, numargs, &error_pos);

		if (expr) {
			res = te_eval(expr);
			pfree(vars);
			pfree(argvalues);
			te_free(expr);
		} else {
			pfree(vars);
			pfree(argvalues);
			ereport(ERROR, errmsg("%.*s<- bad syntax here", error_pos, src));
		}
	} else {
		te_expr* expr;
		expr = te_compile(src, NULL, 0, &error_pos);
		res = te_eval(expr);

		if (expr)
			te_free(expr);
		else
			ereport(ERROR, errmsg("%.*s<- bad syntax here", error_pos, src));
	}

	ReleaseSysCache(proc_tuple);

	PG_RETURN_FLOAT8(res);
}

PG_FUNCTION_INFO_V1(pltinyexpr_validator);
Datum pltinyexpr_validator(PG_FUNCTION_ARGS)
{
	Oid function_oid = PG_GETARG_OID(0);
	Oid prorettype;
	HeapTuple proc_tuple;
	bool is_null;

	int numargs;
	Oid* argtypes;
	char** argnames;
	char* argmodes;

	if (!CheckFunctionValidatorAccess(fcinfo->flinfo->fn_oid, function_oid))
			PG_RETURN_VOID();

	if (!check_function_bodies)
			PG_RETURN_VOID();

	proc_tuple = SearchSysCache(PROCOID, ObjectIdGetDatum(function_oid), 0, 0, 0);
	if (!HeapTupleIsValid(proc_tuple))
		elog(ERROR, "could not find function with oid %u", function_oid);

	prorettype = SysCacheGetAttr(PROCOID, proc_tuple, Anum_pg_proc_prorettype, &is_null);
	if(is_null)
			ereport(ERROR, errmsg("pg_proc.prorettype is NULL"));

	// This already prevents functions from being used as triggers.
	// So it's not necessary to use CALLED_AS_TRIGGER and CALLED_AS_EVENT_TRIGGER
	if(prorettype != FLOAT8OID)
			ereport(ERROR, errmsg("can only return a type of double precision or float8"));

	numargs = get_func_arg_info(proc_tuple, &argtypes, &argnames, &argmodes);

	if(argmodes)
		ereport(ERROR, errmsg("Only IN arguments allowed"));

	for(int i = 0; i < numargs; i++){
		if (argtypes[i] != FLOAT8OID)
			ereport(ERROR, errmsg("only parameters of double precision or float8 types are allowed"));
		if (!argnames)
			ereport(ERROR, errmsg("only named parameters are allowed"));
		if (argnames && strlen(argnames[i]) == 0)
			ereport(ERROR, errmsg("only named parameters are allowed"));
	}

	ReleaseSysCache(proc_tuple);

	PG_RETURN_VOID();
}
