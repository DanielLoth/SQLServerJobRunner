create table dbo.Person (
	PersonNumber bigint not null,
	GivenNames nvarchar(100) not null,
	FamilyName nvarchar(100) not null,

	constraint UC_Person_PK primary key clustered (PersonNumber)
);
go
