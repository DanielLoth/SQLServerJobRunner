create procedure JobRunner.EnsureCategoryExists
    @CategoryName sysname,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;

declare @DatabaseName sysname = db_name();

begin try
    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Checking if category is missing', @DatabaseName = @DatabaseName, @CategoryName = @CategoryName;

    if not exists (select [name] from msdb.dbo.syscategories where [name] = @CategoryName and category_class = 1) /* Class 1 = Job */
    begin
        exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Re-checking if category is missing (with updlock)', @DatabaseName = @DatabaseName, @CategoryName = @CategoryName;

        begin transaction;

        if not exists (select [name] from msdb.dbo.syscategories with (paglock, serializable, updlock) where [name] = @CategoryName and category_class = 1)
        begin
            exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Creating category', @DatabaseName = @DatabaseName, @CategoryName = @CategoryName;
            exec msdb.dbo.sp_add_category @name = @CategoryName;
            exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully created category', @DatabaseName = @DatabaseName, @CategoryName = @CategoryName;
        end

        commit;
    end
end try
begin catch
    if @@trancount != 0 rollback;
    exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error ensuring category exists', @DatabaseName = @DatabaseName, @CategoryName = @CategoryName;
    throw;
end catch

return 0;

go
