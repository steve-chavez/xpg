CREATE FUNCTION pltinyexpr_handler()
RETURNS language_handler
LANGUAGE C AS 'pltinyexpr';

CREATE FUNCTION pltinyexpr_inline_handler(internal)
RETURNS void
LANGUAGE C AS 'pltinyexpr';

CREATE FUNCTION pltinyexpr_validator(oid)
RETURNS void
LANGUAGE C AS 'pltinyexpr';

CREATE TRUSTED LANGUAGE pltinyexpr
HANDLER pltinyexpr_handler
INLINE pltinyexpr_inline_handler
VALIDATOR pltinyexpr_validator;
