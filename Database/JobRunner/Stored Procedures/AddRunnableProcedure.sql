create procedure JobRunner.AddRunnableProcedure
	@JobRunnerName sysname,
	@SchemaName sysname,
	@ProcedureName sysname,
	@IsEnabled bit
as

set nocount, xact_abort on;

declare
	@HasBatchSizeParam bit,
	@HasDoneParam bit,
	@HasExtraParam bit,
	@Sql nvarchar(4000),
	@Msg nvarchar(2000);

if not exists (
	select 1
	from sys.procedures
	where
		object_schema_name(object_id) = @SchemaName and
		object_name(object_id) = @ProcedureName
)
begin
	set @Msg = N'Procedure "' + @SchemaName + N'.' + @ProcedureName + N'" does not exist';
	throw 50000, @Msg, 1;
end

select
	@HasBatchSizeParam = d.HasBatchSizeParam,
	@HasDoneParam = d.HasDoneParam,
	@HasExtraParam = d.HasExtraParam
from sys.procedures p
outer apply (
	select 1 as BatchSizeParam
	from sys.parameters p1
	where
		p.object_id = p1.object_id and
		p1.name = N'@BatchSize' and
		p1.user_type_id = 56 /* 56 = int */
) d1
outer apply (
	select 1 as DoneParam
	from sys.parameters p1
	where
		p.object_id = p1.object_id and
		p1.name = N'@Done'
		and p1.is_output = 1
		and p1.user_type_id = 104 /* 104 = bit */
) d2
outer apply (
	select 1 as ExtraParam
	from sys.parameters p1
	where
		p.object_id = p1.object_id and
		p1.name not in (N'@BatchSize', N'@Done')
) d3
outer apply (
	select
		isnull(cast(d1.BatchSizeParam as bit), 0) as HasBatchSizeParam,
		isnull(cast(d2.DoneParam as bit), 0) as HasDoneParam,
		isnull(cast(d3.ExtraParam as bit), 0) as HasExtraParam
) d
where
	object_schema_name(p.object_id) = @SchemaName and
	object_name(p.object_id) = @ProcedureName;

if @HasExtraParam = 1
begin
	set @Msg =
		N'Procedure "' + @SchemaName + N'.' + @ProcedureName +
		N'" has unsupported parameters. Only the following ' +
		N'parameters are supported: @BatchSize int, @Done bit output';
end

exec JobRunner.GetRunnableProcedure
	@JobRunnerName = @JobRunnerName,
	@SchemaName = @SchemaName,
	@ProcedureName = @ProcedureName,
	@HasBatchSizeParam = @HasBatchSizeParam,
	@HasDoneParam = @HasDoneParam,
	@GeneratedProcedureSql = @Sql output;

merge JobRunner.RunnableProcedure with (serializable, updlock, rowlock) t
using (
	select
		@JobRunnerName as JobRunnerName,
		@SchemaName as SchemaName,
		@ProcedureName as ProcedureName,
		@IsEnabled as IsEnabled,
		@Sql as GeneratedProcedureWrapperSql
) s
on
	t.JobRunnerName = s.JobRunnerName and
	t.SchemaName = s.SchemaName and
	t.ProcedureName = s.ProcedureName
when matched then
	update
	set
		t.IsEnabled = s.IsEnabled,
		t.LastElapsedMilliseconds = 0,
		t.ExecTimeViolationCount = 0,
		t.GeneratedProcedureWrapperSql = s.GeneratedProcedureWrapperSql
when not matched by target then
	insert (JobRunnerName, SchemaName, ProcedureName, IsEnabled, GeneratedProcedureWrapperSql)
	values (s.JobRunnerName, s.SchemaName, s.ProcedureName, s.IsEnabled, s.GeneratedProcedureWrapperSql);

return 0;

go
