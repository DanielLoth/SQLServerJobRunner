create table JobRunner.Config (
    JobRunnerName sysname not null,
    ScheduleName sysname not null,
    CategoryName sysname not null,
    OwnerLoginName sysname not null
        constraint JobRunner_Config_OwnerLoginName_DF default N'sa',
    ServerName sysname not null
        constraint JobRunner_Config_ServerName_DF default N'(local)',
    Mode nvarchar(20) not null
        constraint JobRunner_Config_Mode_DF default N'Recurring',
    RecurringSecondsInterval int not null
        constraint JobRunner_Config_RecurringSecondsInterval_DF default 20,
    JobRunnerDescription nvarchar(512) not null
        constraint JobRunner_Config_JobRunnerDescription default N'',
    TargetJobRunnerExecTimeMilliseconds int not null
        constraint JobRunner_Config_TargetJobRunnerExecTimeMilliseconds_DF default 30000,
    [BatchSize] int not null
        constraint JobRunner_Config_BatchSize_DF default 500,
    DeadlockPriority int not null
        constraint JobRunner_Config_DeadlockPriority_DF default -5,
    LockTimeoutMilliseconds int not null
        constraint JobRunner_Config_LockTimeoutMilliseconds_DF default -1,
    MaxSyncSecondaryCommitLatencyMilliseconds bigint not null
        constraint JobRunner_Config_MaxSyncSecondaryCommitLatencyMilliseconds_DF default 1000,
    MaxAsyncSecondaryCommitLatencyMilliseconds bigint not null
        constraint JobRunner_Config_MaxAsyncSecondaryCommitLatencyMilliseconds_DF default 5000,
    MaxSyncSecondaryRedoQueueSize bigint not null
        constraint JobRunner_Config_MaxSyncSecondaryRedoQueueSize_DF default 300,
    MaxAsyncSecondaryRedoQueueSize bigint not null
        constraint JobRunner_Config_MaxAsyncSecondaryRedoQueueSize_DF default 5000,
    MaxProcedureExecutionTimeViolationCount int not null
        constraint JobRunner_Config_MaxProcedureExecutionTimeViolationCount_DF default 5,
    MaxProcedureExecutionFailureCount int not null
        constraint JobRunner_Config_MaxProcedureExecutionFailureCount_DF default 5,
    MaxProcedureExecutionTimeMilliseconds int not null
        constraint JobRunner_Config_MaxProcedureExecutionTimeMilliseconds_DF default 2000,
    BatchSleepMilliseconds int not null
        constraint JobRunner_Config_BatchSleepMilliseconds_DF default 250,
    ResetViolationCountToZeroOnDeploy bit not null
        constraint JobRunner_Config_ResetViolationCountToZeroOnDeploy_DF default 0,
    ResetDoneFlagToFalseOnDeploy bit not null
        constraint JobRunner_Config_ResetDoneFlagToFalseOnDeploy_DF default 0,
    ResetEnabledFlagToTrueOnDeploy bit not null
        constraint JobRunner_Config_ResetEnabledFlagToTrueOnDeploy_DF default 1,
    ResetErrorColumnsOnDeploy bit not null
        constraint JobRunner_Config_ResetErrorColumnsOnDeploy_DF default 1,
    ResetExecutionCountersOnDeploy bit not null
        constraint JobRunner_Config_ResetExecutionCountersOnDeploy_DF default 0,

    constraint UC_JobRunner_Config_PK
    primary key clustered (JobRunnerName),

    constraint JobRunner_Config_Has_Valid_DeadlockPriority_CK
    check (DeadlockPriority >= -10 and DeadlockPriority <= 10),

    constraint JobRunner_Config_Has_Valid_LockTimeoutMilliseconds_CK
    check (
        LockTimeoutMilliseconds = -1
        or LockTimeoutMilliseconds = 0
        or LockTimeoutMilliseconds = 1000
        or LockTimeoutMilliseconds = 2000
        or LockTimeoutMilliseconds = 3000
        or LockTimeoutMilliseconds = 4000
        or LockTimeoutMilliseconds = 5000
        or LockTimeoutMilliseconds = 6000
        or LockTimeoutMilliseconds = 7000
        or LockTimeoutMilliseconds = 8000
        or LockTimeoutMilliseconds = 9000
        or LockTimeoutMilliseconds = 10000
        or LockTimeoutMilliseconds = 15000
        or LockTimeoutMilliseconds = 30000
        or LockTimeoutMilliseconds = 60000
        or LockTimeoutMilliseconds = 120000
    ),

    constraint JobRunner_Config_Has_Acceptable_BatchSize_CK
    check ([BatchSize] >= 1 and [BatchSize] <= 5000),

    constraint JobRunner_Config_Has_Acceptable_BatchSleepMilliseconds_CK
    check (BatchSleepMilliseconds >= 0 and BatchSleepMilliseconds <= 10000),

    constraint JobRunner_Config_Has_Acceptable_Mode_CK
    check (Mode = N'CPUIdle' or Mode = N'Recurring'),

    constraint JobRunner_Config_RecurringSecondsInterval_When_Mode_CPUIdle_CK
    check (Mode = N'CPUIdle' and RecurringSecondsInterval = 0 or Mode != N'CPUIdle')
);
