# SQL Server Job Runner

Make it easy for developers to run background jobs - safely.

## Contributing

I'm happy to accept contributions to this code via pull request. Please reach out to discuss before committing substantial time to writing any code though.

If you have any ideas or suggestions please [start a discussion](https://github.com/DanielLoth/SQLServerJobRunner/discussions).

If you find any bugs please [raise an issue](https://github.com/DanielLoth/SQLServerJobRunner/issues).

## Quick start

You can build and deploy an example database - `JobRunnerExample` - and deploy it to `localhost`.

Firstly, run the following command:
```
.\build.cmd
```

Secondly, run the following command - and when prompted, specify 'y' if you'd like to have the demo data and configuration deployed.
```
.\deploy.cmd
```

Key things to look for:
- There'll be a new database named `JobRunnerExample`
- There'll be two new SQL Agent jobs:
   - `Job Runner - JobRunnerExample` is configured to run every 20 seconds (it'll only start if it isn't already running)
   - `Job Runner (Idle CPU) - JobRunnerExample` is configured to run whenever the server has been relatively idle for a period of time
- The `JobRunner.Config` table contains one row for each configured job runner
- The `JobRunner.RunnableProcedure` table contains one row per job procedure, with each row including error details, metrics, and whether or not the job is enabled or done.

Additional stuff in the demo:
- There'll be a number of job procedures configured to run. These serve to demonstrate the features available.
   - Some will run too slowly, exceeding their time limit and ultimately being disabled due to violating the rules
   - Some will fail with other errors - non-zero return codes, throwing exceptions, leaving a transaction open, etc.
   - One will indicate that it is done
   - One will update a table - `dbo.GuidVal` - and acts as a demonstration of a very basic backfill (i.e., putting values into a newly added column)
- 

Notes:
- You'll need `sysadmin` to deploy locally, or a login with the role `SQLAgentOperatorRole`
- `deploy.cmd` makes use of `integrated security`. It is also configured to use encryption, and to trust the server certificate.

## Using this code

SQL Server Job Runner is designed to integrate with the SqlPackage.exe deployment process. Developers can write code in a post-deployment script to create one or more job runners, and to assign one or more jobs to those runners.

Perhaps the easiest way to use this software is to incorporate the relevant `*.sql` files (for tables, stored procedures, and the schema) in your existing database `SqlProj` project file. 

To add a job runner, you can add the following to the post-deployment script:

```sql
declare @DatabaseName sysname = db_name();
declare @JobRunnerName sysname = N'Job Runner - ' + @DatabaseName;

/* Use a valid category name here, based on what's in your instance of SQL Server */
declare @CategoryName sysname = N'Database Maintenance';

exec JobRunner.AddAgentJob
    @JobRunnerName = @JobRunnerName,
    @CategoryName = @CategoryName,
    @ServerName = N'(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa',
    @Mode = N'Recurring',
    @RecurringSecondsInterval = 10,
    @DeleteJobHistory = 1;
```

To add a job to the runner, you can add the following to the post-deployment script:

```sql
exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'MyJobProcedure',
    @IsEnabledOnCreation = 1;
```

A job runner will fail from the outset if it does not have a `JobRunner.Config` record present. The error logging in the SQL Agent job's history screen will notify you to this if the configuration is missing.

The following query demonstrates one way to add a `JobRunner.Config` row to the table via the post-deployment script:

```sql
declare @JobConfig table (
	JobRunnerName sysname not null,
	TargetJobRunnerExecTimeMilliseconds int not null,
	[BatchSize] int not null,
	DeadlockPriority int not null,
	LockTimeoutMilliseconds int not null,
	MaxSyncSecondaryCommitLatencyMilliseconds bigint not null,
	MaxAsyncSecondaryCommitLatencyMilliseconds bigint not null,
	MaxSyncSecondaryRedoQueueSize bigint not null,
	MaxAsyncSecondaryRedoQueueSize bigint not null,
	MaxProcedureExecutionTimeViolationCount int not null,
    MaxProcedureExecutionFailureCount int not null,
	MaxProcedureExecutionTimeMilliseconds int not null,
	BatchSleepMilliseconds int not null,
    ResetViolationCountToZeroOnDeploy bit not null,
    ResetDoneFlagToFalseOnDeploy bit not null,
    ResetEnabledFlagToTrueOnDeploy bit not null,
    ResetErrorColumnsOnDeploy bit not null,
    ResetExecutionCountersOnDeploy bit not null,

    primary key (JobRunnerName)
);

insert into @JobConfig (
    JobRunnerName,
    TargetJobRunnerExecTimeMilliseconds,
    [BatchSize],
    DeadlockPriority,
    LockTimeoutMilliseconds,
    MaxSyncSecondaryCommitLatencyMilliseconds,
    MaxAsyncSecondaryCommitLatencyMilliseconds,
    MaxSyncSecondaryRedoQueueSize,
    MaxAsyncSecondaryRedoQueueSize,
    MaxProcedureExecutionTimeViolationCount,
    MaxProcedureExecutionFailureCount,
    MaxProcedureExecutionTimeMilliseconds,
    BatchSleepMilliseconds,
    ResetViolationCountToZeroOnDeploy,
    ResetDoneFlagToFalseOnDeploy,
    ResetEnabledFlagToTrueOnDeploy,
    ResetErrorColumnsOnDeploy,
    ResetExecutionCountersOnDeploy
)
values
    (@JobRunnerName, 30000, 1000, -5, 3000, 1000, 5000, 300, 5000, 5, 5, 500, 500, 1, 1, 1, 1, 1);

merge JobRunner.Config with (serializable, updlock) t
using @JobConfig s
on t.JobRunnerName = s.JobRunnerName
when matched then
    update
    set
        t.TargetJobRunnerExecTimeMilliseconds = s.TargetJobRunnerExecTimeMilliseconds,
        t.[BatchSize] = s.[BatchSize],
        t.DeadlockPriority = s.DeadlockPriority,
        t.LockTimeoutMilliseconds = s.LockTimeoutMilliseconds,
        t.MaxSyncSecondaryCommitLatencyMilliseconds = s.MaxSyncSecondaryCommitLatencyMilliseconds,
        t.MaxAsyncSecondaryCommitLatencyMilliseconds = s.MaxAsyncSecondaryCommitLatencyMilliseconds,
        t.MaxSyncSecondaryRedoQueueSize = s.MaxSyncSecondaryRedoQueueSize,
        t.MaxAsyncSecondaryRedoQueueSize = s.MaxAsyncSecondaryRedoQueueSize,
        t.MaxProcedureExecutionTimeViolationCount = s.MaxProcedureExecutionTimeViolationCount,
        t.MaxProcedureExecutionFailureCount = s.MaxProcedureExecutionFailureCount,
        t.MaxProcedureExecutionTimeMilliseconds = s.MaxProcedureExecutionTimeMilliseconds,
        t.BatchSleepMilliseconds = s.BatchSleepMilliseconds,
        t.ResetViolationCountToZeroOnDeploy = s.ResetViolationCountToZeroOnDeploy,
        t.ResetDoneFlagToFalseOnDeploy = s.ResetDoneFlagToFalseOnDeploy,
        t.ResetEnabledFlagToTrueOnDeploy = s.ResetEnabledFlagToTrueOnDeploy,
        t.ResetErrorColumnsOnDeploy = s.ResetErrorColumnsOnDeploy,
        t.ResetExecutionCountersOnDeploy = s.ResetExecutionCountersOnDeploy
when not matched by target then
    insert (
        JobRunnerName,
        TargetJobRunnerExecTimeMilliseconds,
        [BatchSize],
        DeadlockPriority,
        LockTimeoutMilliseconds,
        MaxSyncSecondaryCommitLatencyMilliseconds,
        MaxAsyncSecondaryCommitLatencyMilliseconds,
        MaxSyncSecondaryRedoQueueSize,
        MaxAsyncSecondaryRedoQueueSize,
        MaxProcedureExecutionTimeViolationCount,
        MaxProcedureExecutionFailureCount,
        MaxProcedureExecutionTimeMilliseconds,
        BatchSleepMilliseconds,
        ResetViolationCountToZeroOnDeploy,
        ResetDoneFlagToFalseOnDeploy,
        ResetEnabledFlagToTrueOnDeploy,
        ResetErrorColumnsOnDeploy,
        ResetExecutionCountersOnDeploy
    )
    values (
        JobRunnerName,
        TargetJobRunnerExecTimeMilliseconds,
        [BatchSize],
        DeadlockPriority,
        LockTimeoutMilliseconds,
        MaxSyncSecondaryCommitLatencyMilliseconds,
        MaxAsyncSecondaryCommitLatencyMilliseconds,
        MaxSyncSecondaryRedoQueueSize,
        MaxAsyncSecondaryRedoQueueSize,
        MaxProcedureExecutionTimeViolationCount,
        MaxProcedureExecutionFailureCount,
        MaxProcedureExecutionTimeMilliseconds,
        BatchSleepMilliseconds,
        ResetViolationCountToZeroOnDeploy,
        ResetDoneFlagToFalseOnDeploy,
        ResetEnabledFlagToTrueOnDeploy,
        ResetErrorColumnsOnDeploy,
        ResetExecutionCountersOnDeploy
    )
when not matched by source then
    delete;
```

## Security

Your `SqlPackage.exe` database deployments will not need to use the `sysadmin` login to use this software.

The following table outlines the privileged stored procedures used by this software to configure the SQL Agent jobs.

| Privileged procedure | Required SQL Server role |
| -- | -- |
| msdb.dbo.sp_add_job | SQLAgentOperatorRole |
| msdb.dbo.sp_update_job | SQLAgentOperatorRole |
| msdb.dbo.sp_delete_job | SQLAgentOperatorRole |
| msdb.dbo.sp_add_jobstep | SQLAgentOperatorRole |
| msdb.dbo.sp_add_jobserver | SQLAgentOperatorRole |
| msdb.dbo.sp_add_schedule | SQLAgentOperatorRole |
| msdb.dbo.sp_update_schedule | SQLAgentOperatorRole |
| msdb.dbo.sp_attach_schedule | SQLAgentOperatorRole |

The SQL Server login that you use to deploy (e.g.: via `SqlPackage.exe` or similar) will require this `SQLAgentOperatorRole` role.

For more information refer to [SQL Server Agent Fixed Database Roles](https://learn.microsoft.com/en-us/sql/ssms/agent/sql-server-agent-fixed-database-roles?view=sql-server-ver16).
