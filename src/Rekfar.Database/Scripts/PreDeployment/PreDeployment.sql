/*
    Pre-deployment script — runs before every publish, in every environment.

    This is where a removal is made explicit. DropObjectsNotInSource is off in both
    publish profiles, so deleting an object's .sql file removes it from the model but
    leaves it in a database that already has it. Each retired object gets a script here
    that drops it — and refuses to, failing the deploy, if doing so would discard data.

    Everything here must be idempotent and must tolerate an empty database: on a fresh
    one there is nothing to drop, and on the second publish there is nothing left to.

    Exactly one pre-deployment file is allowed per project, so it includes the rest.
*/

:r ./Drop.DiaryNote.sql
