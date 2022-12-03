create table JobRunner.[Database] (
    DatabaseName sysname,
    FirstSeenDtmUtc datetime2(0) default getutcdate(),
    LastSeenDtmUtc datetime2(0) default getutcdate(),
    IsDeleted bit not null default 0,
    HardDeletionDtmUtc datetime2(0),
    ErrorNumber int,
    ErrorMessage nvarchar(4000),
    ErrorSeverity int,
    ErrorState int,
    ErrorDtmUtc datetime2,

    constraint UC_JobRunner_Database_PK
    primary key clustered (DatabaseName)
);
