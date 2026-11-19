/*
    app.DiaryNote is retired: the private diary note is Trip.Notes (ADR-0020).

    Nothing ever wrote to the table — no backend module mapped it — so it is expected to
    be empty wherever it still exists. That is checked rather than assumed: if a row is
    found the deploy stops here, before anything has changed. The fix is then a script
    that moves the notes into app.Trip.Notes ahead of this one, not removing the check.

    Dynamic SQL because the table is no longer in the model, and a database published
    from empty never had it.
*/
IF OBJECT_ID(N'app.DiaryNote', N'U') IS NOT NULL
BEGIN
    DECLARE @diaryNoteRows int;
    EXEC sys.sp_executesql N'SELECT @n = COUNT(*) FROM app.DiaryNote;', N'@n int OUTPUT', @n = @diaryNoteRows OUTPUT;

    IF @diaryNoteRows > 0
        THROW 51000, 'app.DiaryNote holds rows. Move them into app.Trip.Notes with a pre-deployment script before dropping the table (docs/conventions.md, "Changing the schema").', 1;

    EXEC sys.sp_executesql N'DROP TABLE app.DiaryNote;';
    PRINT 'Dropped the empty table app.DiaryNote (ADR-0020).';
END
GO
