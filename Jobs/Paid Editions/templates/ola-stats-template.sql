-- Update Statistics
-- Set here the !!SQLBackupPath!! (not trailing backslash!)
-- Set here the !!database_maintenance!! - where the Maintenance Solution is installed, normally cs_helper.
-- Set here the !!LogPath!! - Path to where you want to save the logs (Instance Log path by default).
-- Set here the !!operator!! - Not the email address, but the defined operator in Database MailConfig.
-- Set here the !!FriendlyName!! - Customer name or application.
-- Set here the !!Instance!! - Hostname\Instance

USE [msdb]

GO
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Maintenance Solution' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Maintenance Solution'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Stat - ALL_DATABASES', 
                @enabled=1, 
                @notify_level_eventlog=2, 
                @notify_level_email=0, 
                @notify_level_netsend=0, 
                @notify_level_page=0, 
                @delete_level=0, 
                @description=N'Do a full update statistics of all databases using Ola''s solution', 
                @category_name=N'Maintenance Solution', 
                @owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Launch maintenance solution', 
                @step_id=1, 
                @cmdexec_success_code=0, 
                @on_success_action=4, 
                @on_success_step_id=2, 
                @on_fail_action=4, 
                @on_fail_step_id=3, 
                @retry_attempts=0, 
                @retry_interval=0, 
                @os_run_priority=0, @subsystem=N'CmdExec', 
                @command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d !!database_maintenance!! -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''ALL_DATABASES'',@FragmentationLow = NULL,@FragmentationMedium = NULL,@FragmentationHigh = NULL,@UpdateStatistics = ''ALL'',@LogToTable=''Y''" -b', 
                @output_file_name=N'!!LogPath!!\UpdateStatistics_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt', 
                @flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Notify operator OK', 
                @step_id=2, 
                @cmdexec_success_code=0, 
                @on_success_action=1, 
                @on_success_step_id=0, 
                @on_fail_action=2, 
                @on_fail_step_id=0, 
                @retry_attempts=0, 
                @retry_interval=0, 
                @os_run_priority=0, @subsystem=N'TSQL', 
                @command=N'EXECUTE msdb.dbo.sp_notify_operator @name=N''!!operator!!'',@subject=N''[!!FriendlyName!!] [!!Instance!!] [OK] UpdateStats - ALL_DATABASES'',@body=N''All Databases from !!instance!! have their statistics updated.''
', 
                @database_name=N'!!database_maintenance!!', 
                @flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Notify Operator Error', 
                @step_id=3, 
                @cmdexec_success_code=0, 
                @on_success_action=1, 
                @on_success_step_id=0, 
                @on_fail_action=2, 
                @on_fail_step_id=0, 
                @retry_attempts=0, 
                @retry_interval=0, 
                @os_run_priority=0, @subsystem=N'TSQL', 
                @command=N'EXECUTE msdb.dbo.sp_notify_operator @name=N''!!operator!!'',@subject=N''[!!FriendlyName!!] [!!Instance!!] [KO] UpdateStats - ALL_DATABASES'',@body=N''Some databases in !!instance!! failed to have their statistics updated. Please check the CommandLog table in !!database_maintenance!! to know more about the error''
', 
                @database_name=N'!!database_maintenance!!', 
                @flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Schedule for Stat - ALL_DATABASES', 
                @enabled=1, 
                @freq_type=8, 
                @freq_interval=62, 
                @freq_subday_type=1, 
                @freq_subday_interval=0, 
                @freq_relative_interval=0, 
                @freq_recurrence_factor=1, 
                @active_start_date=20131216, 
                @active_end_date=99991231, 
                @active_start_time=212000, 
                @active_end_time=235959, 
                @schedule_uid=N'2a75c13c-511d-47b7-bbbb-1058a6b12afd'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO