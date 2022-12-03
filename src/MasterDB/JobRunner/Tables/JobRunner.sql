create table JobRunner.JobRunner (
    DatabaseName sysname not null,
    JobRunnerName sysname not null,
    ScheduleName sysname not null,
    CategoryName sysname not null,
    OwnerLoginName sysname not null,
    ServerName sysname not null,
    Mode nvarchar(20) not null,
    RecurringSecondsInterval int not null,
    JobRunnerDescription nvarchar(512) not null,
    ReplacementRequired bit not null default 0,
    FirstSeenDtmUtc datetime2(0) default getutcdate(),
    LastSeenDtmUtc datetime2(0) default getutcdate(),
    IsDeleted bit not null default 0,
    HardDeletionDtmUtc datetime2(0),
    ErrorNumber int,
    ErrorMessage nvarchar(4000),
    ErrorSeverity int,
    ErrorState int,
    ErrorDtmUtc datetime2,

    constraint UC_JobRunner_JobRunner_PK
    primary key clustered (DatabaseName, JobRunnerName)
);
