CREATE TABLE IF NOT EXISTS agoston_metadata.agoston_metadata (
    version varchar(10) UNIQUE
);

CREATE OR REPLACE FUNCTION agoston_api.get_backend_version ()
    RETURNS varchar (
        10)
    LANGUAGE plpgsql
    AS $$
DECLARE
    d_version varchar(10);
BEGIN
    SELECT
        version INTO d_version
    FROM
        agoston_metadata.agoston_metadata;
    RETURN d_version;
END;
$$;

CREATE OR REPLACE FUNCTION agoston_api.set_backend_version (p_version varchar(10))
    RETURNS varchar (
        10)
    LANGUAGE plpgsql
    AS $$
DECLARE
    d_version varchar(10);
BEGIN
    IF NOT EXISTS (
        SELECT
            1
        FROM
            agoston_metadata.agoston_metadata) THEN
    INSERT INTO agoston_metadata.agoston_metadata (version)
        VALUES (p_version)
    RETURNING
        version INTO d_version;
ELSE
    UPDATE
        agoston_metadata.agoston_metadata
    SET
        version = p_version
    RETURNING
        version INTO d_version;
END IF;
    RETURN d_version;
END;
$$;

