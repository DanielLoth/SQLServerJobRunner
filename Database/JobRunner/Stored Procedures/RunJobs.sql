create procedure JobRunner.RunJobs
	@JobRunnerName sysname
as

set nocount, xact_abort on;
set deadlock_priority low;

declare
	@LockTimeoutSeconds int = -1, /* Default lock timeout, infinite wait */
	@DeadlockPriority int = 0, /* Default deadlock priority */
	@StartDtmUtc datetime2(0) = getutcdate();

if @LockTimeoutSeconds = -1 set lock_timeout -1; /* Wait forever */
else if @LockTimeoutSeconds = 0 set lock_timeout 0; /* Don't wait at all */
else if @LockTimeoutSeconds = 1 set lock_timeout 1000;
else if @LockTimeoutSeconds = 2 set lock_timeout 2000;
else if @LockTimeoutSeconds = 3 set lock_timeout 3000;
else if @LockTimeoutSeconds = 4 set lock_timeout 4000;
else if @LockTimeoutSeconds = 5 set lock_timeout 5000;
else if @LockTimeoutSeconds = 6 set lock_timeout 6000;
else if @LockTimeoutSeconds = 7 set lock_timeout 7000;
else if @LockTimeoutSeconds = 8 set lock_timeout 8000;
else if @LockTimeoutSeconds = 9 set lock_timeout 9000;
else if @LockTimeoutSeconds = 10 set lock_timeout 10000;
else if @LockTimeoutSeconds = 15 set lock_timeout 15000;
else if @LockTimeoutSeconds = 30 set lock_timeout 30000;
else if @LockTimeoutSeconds = 60 set lock_timeout 60000;
else if @LockTimeoutSeconds = 120 set lock_timeout 120000;

waitfor delay '00:00:59';

go
