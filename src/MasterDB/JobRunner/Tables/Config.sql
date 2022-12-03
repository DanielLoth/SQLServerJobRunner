create table JobRunner.Config (
    RowNumber int not null,
    LogToTable bit not null,
    MinimumLevelToLogToTable char(3) not null,
    RetentionPeriodMinutes int not null,

    constraint UC_JobRunner_Config_PK
    primary key clustered (RowNumber),

    constraint JobRunner_Config_HasSingleRow_CK
    check (RowNumber = 1),

    constraint JobRunner_Config_MinimumLevelToLog_IsValid_CK
    check (
        MinimumLevelToLogToTable = 'ERR'
        or MinimumLevelToLogToTable = 'WRN'
        or MinimumLevelToLogToTable = 'INF'
        or MinimumLevelToLogToTable = 'DBG'
        or MinimumLevelToLogToTable = 'VRB'
    )
);
