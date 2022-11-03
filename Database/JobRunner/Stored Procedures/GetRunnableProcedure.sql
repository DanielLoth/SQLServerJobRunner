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

exec @Result = [%%SchemaName%%].[%%ProcedureName%%] %%ParamList%%;

return @Result;
';

declare @ParamListSql nvarchar(200) = N'';
set @ParamListSql += case when @HasBatchSizeParam = 1 then '@BatchSize = @BatchSize' else '' end;
set @ParamListSql += case when @HasBatchSizeParam = 1 and @HasDoneParam = 1 then ', ' else '' end;
set @ParamListSql += case when @HasDoneParam = 1 then '@Done = @Done' else '' end;

--set @Sql = replace(@Sql, '%%JobRunnerName%%', @JobRunnerName);
set @Sql = replace(@Sql, '%%SchemaName%%', @SchemaName);
set @Sql = replace(@Sql, '%%ProcedureName%%', @ProcedureName);
set @Sql = replace(@Sql, '%%ParamList%%', @ParamListSql);

set @GeneratedProcedureSql = @Sql;

return 0;

go
