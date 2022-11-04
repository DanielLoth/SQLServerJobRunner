create procedure JobRunner.GetRunnableProcedure
	@JobRunnerName sysname,
	@SchemaName sysname,
	@ProcedureName sysname,
	@HasBatchSizeParam bit,
	@HasDoneParam bit,
	@GeneratedProcedureSql nvarchar(4000) output
as

declare @Sql nvarchar(4000) = N'
create or alter procedure [#JobRunnerWrapper]
	@BatchSize int,
	@Done bit output
as

declare @Result int = 0;

exec @Result = [%%SchemaName%%].[%%ProcedureName%%]%%ParamList%%

return @Result;
';

declare @ParamListSql nvarchar(200) = N'';
set @ParamListSql += case when @HasBatchSizeParam = 1 then N' @BatchSize = @BatchSize' else N'' end;
set @ParamListSql += case when @HasBatchSizeParam = 1 and @HasDoneParam = 1 then N',' else N'' end;
set @ParamListSql += case when @HasDoneParam = 1 then N' @Done = @Done' else N'' end;
set @ParamListSql += N';';

set @Sql = replace(@Sql, N'%%SchemaName%%', @SchemaName);
set @Sql = replace(@Sql, N'%%ProcedureName%%', @ProcedureName);
set @Sql = replace(@Sql, N'%%ParamList%%', @ParamListSql);

set @GeneratedProcedureSql = @Sql;

return 0;

go
