create procedure JobRunner.CreateRunnableProcedure
	@JobRunnerName sysname,
	@SchemaName sysname,
	@ProcedureName sysname,
	@HasBatchSizeParam bit,
	@HasDoneParam bit
as

declare @Result int = 0;

declare @Sql nvarchar(2000) = N'
create or alter procedure [#%%JobRunnerName%%]
	@BatchSize int,
	@Done bit output
as

declare @Result int = 0;

exec @Result = [%%SchemaName%%].[%%ProcedureName%%] %%BatchSizeArg%% %%DoneArg%%;

return @Result;
';

set @Sql = replace(@Sql, '%%JobRunnerName%%', @JobRunnerName);
set @Sql = replace(@Sql, '%%SchemaName%%', @SchemaName);
set @Sql = replace(@Sql, '%%ProcedureName%%', @ProcedureName);

set @Sql = replace(
	@Sql,
	'%%BatchSizeArg%%',
	case when @HasBatchSizeParam = 1 then '@BatchSize = @BatchSize,' else '' end
);

set @Sql = replace(
	@Sql,
	'%%DoneArg%%',
	case when @HasDoneParam = 1 then '@Done = @Done output' else '' end
);

exec @Result = sp_executesql @stmt = @Sql;

return @Result;

go
