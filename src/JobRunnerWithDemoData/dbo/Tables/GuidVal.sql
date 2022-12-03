create table dbo.GuidVal (
    Val uniqueidentifier not null,
    LastUpdatedDtmUtc datetime2(0),

    constraint UC_GuidVal_PK primary key (Val)
);
