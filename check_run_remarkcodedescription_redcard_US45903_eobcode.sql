USE [mcr_dc_prod]
GO
/****** Object:  StoredProcedure [dbo].[check_run_remarkcodedescription_redcard]    Script Date: 7/7/2026 3:29:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER   PROCEDURE [dbo].[check_run_remarkcodedescription_redcard]
	@check_run_id [int],
	@modified_user_id [int],
	@voucher_id [int],
	--@claim_id [int],		--removing these AJ 41962
	--@claim_ud [varCHAR] (25),
	@doc_type [char] (5) ,
	@doc_id  [CHAR] (25) ,
	@line_number [int]	output				-- line number in the @record table 
	
WITH EXECUTE AS CALLER
AS
/** ---------------------------------------------------------------------------------------------------------
	 called from check_run_master_redcard to generate the remarkcode descriptions for the claim procedure lines on the voucher 
	 (the remarks which print at the bottom of the EOB and EOP)
	 These are all tab delimited files
	
	
	RemarkCodedescription 
	cRecordType					2	Always 21
	cRecordVersion				2	Record Type Version 08
	cDocId						25
	cRemarkCode					10	Remark Code
	cRemarkDescription			1200	-- US#45903: Updated from 1000 to 1200 to match payment file spec
	cClaimNumber				25
	cLineNumber					4	Service Line Number
	cAmount						15	Remark Code Amount
	cRemarkDescription2			100	Remark Code Description 2
	cRemarkCodeType				10	Remark Code Type
				1202 Total Length

	03/09/2017 Modified if an EOB select from check_run_redcard_remark based on Doc_id 
	09/25/2017 Modified to put the Line and line numbers at the beginning of the remark not at the end. 
	01/16/2018 Modified to add a join for doc_id in another place 
	12/18/2019 Modified to not put a line number on the accumulator remark codes 
	02/12/2020 Modified to make the remark code be unique for accumulators, it will be the first 3 chars of the the remark descirption and the @remark_id 
	02/06/2025 JC - US #34679 - Update @remark_code length to 20 characters, removed logic that trims the remark description to the first 3 characters from the left + @remark_id and replace it with '*'
						      - Remove Elva's email and add Tracy's and Juan's email to receive the notification via email
	03/05/2025 JC - US #34679 - Update '*' to 010
	06/15/2026 AJ - US #41962 - Update record version to 08 and add logging
	06/17/2026    - US#45903  - Extract real remark code from front of description text instead of hardcoding '010'
	                          - Strip remark code from description to avoid duplication in cRemarkDescription field
	                          - Raise @line_and_remark and cRemarkDescription field length from 1000 to 1200 to match payment file spec
	                          - Replace single record write with chunking logic: when line number list + description
	                            exceeds 1200 chars, split into multiple Record 21 entries each carrying the same
	                            remark code with description appended at end of each chunk — no lines truncated
	08/07/2026 AJ - US #41962 - removing claim_id and ud from the parameter list and elsewhere
	08/11/2026    - US#45903  - Populate cRemarkCode from dbo.eob.eob_ud using check_run_redcard_remark.eob_id
	                          - Keep the original remark text in cRemarkDescription (do not split/strip the EOB code from the description)
	                          - Retain the 1200-character Record 21 description/chunking logic
--------------------------------------------------------------------------------------------------------------**/
-- Local Variables
----------------------------------------
    DECLARE @return_status				int
    DECLARE @record						CHAR(1467)
	declare @rectot						CHAR(826)
	declare @recremark					CHAR(1493)	-- AJ 41962 06/15/2026
	declare @tab						char
	declare @fd							char
	declare @fq							char
	declare @zero						char(15)
    
    declare @work_amount				money		-- elva added 09/02/2011
    declare @work_int					int			-- elva added 09/02/2011
	declare @workfield					varchar(6)	-- the character counter of docid 
	DECLARE @eob_remark_code_id         int			-- copied from check_run_eop

	declare @record_count				int	
	declare @record_id					int	
	declare @remark_count				int	
	declare @remark_id					int	
	declare @remark_line_count			int
	declare @remark_line_id				int 
	declare @remark_code				char(10)	-- elva 02/12/2020

	-- Error log
	DECLARE @error_message				varchar(2000)

	declare @email_body					varchar(max)
	declare @email_subject				varchar(200)
	DECLARE @recipients					varchar(100)
	set @email_body = null
	set @email_subject = null
	set @recipients	= 'tech.operations@webtpa.com;tracy.smith@webtpa.com;juan.calvillo@webtpa.com'
	-- 02/06/2025 removed elva.bass@webtpa.com and added tracy.smith@webtpa.com and juan.calvillo@webtpa.com

	DECLARE @servicelinesequence_char	char(6)
	DECLARE @claim_line_sequence_char	char(3)
	DECLARE @first_time					bit
	declare @servicelinenumber			int		-- the number of occurrences of the service line 
	declare @servicelinenumber_char		char(3)
	declare @save_claim_procid			int 

	-- ==========================================
	-- US#45903: Variables for EOB remark code lookup and 1200-character splitting logic
	-- ==========================================
	DECLARE @eob_id						INT
	DECLARE @clean_description			VARCHAR(1200)	-- original remark text is retained as-is
	DECLARE @chunk						VARCHAR(1200)	-- current line number chunk being built
	DECLARE @chunk_line_part			VARCHAR(10)		-- one line number token e.g. " 181," or " 181;"
	DECLARE @available_chars			INT				-- chars available for line numbers = 1200 - LEN(desc suffix)
	DECLARE @desc_suffix				VARCHAR(1210)	-- "; clean_description" appended to end of each chunk
	DECLARE @is_last_line				BIT				-- 1 if this is the last line number for this remark
	-- ==========================================

--drop table #remark_table 
	create table #remark_table  (
	remark_id			INT IDENTITY(1,1) PRIMARY KEY
	,	remark				VARCHAR(450)
	,	remark_type			VARCHAR(10)
	,	eob_id				INT
	,	clinical_edit_id	INT					
	)

--drop table #remark_line_table 
	create table #remark_line_table  (
	remark_line_id		INT IDENTITY(1,1) PRIMARY KEY
	, remark_id			int 
	,	line_number 	int
	,   remark			varchar(450)
	,	remark_type		VARCHAR(10)
	)

	declare @remark_description			VARCHAR(450)
	DECLARE @remark_type				VARCHAR(10)

	-- ==========================================
	-- US#45903: Increased @line_and_remark from varchar(1000) to varchar(1200)
	--           to match payment file field length and prevent truncation
	-- ==========================================
	declare @line_and_remark			varchar(1200)	-- was varchar(1000) -- AJ 41962
	-- ==========================================

	declare @line_description			varchar(1000)
	declare @rmk_line_number			int 

	-----------------------------------------------
    -- Initialize Variables
    -----------------------------------------------
    SET @return_status = 0
	set @fd = ','
	set @fq = '"'
	set @tab = CHAR(9)

begin try 

	-- elva 03/09/2017 if EOP we want all remark codes
	-- if EOB we only want the remark codes for the @doc_id with this claim 
	if @doc_type = 'EOP'
		insert into #remark_table (remark, remark_type, eob_id, clinical_edit_id)
		select distinct remark, remark_type, eob_id, clinical_edit_id 
		from check_run_redcard_remark 
		where check_run_id = @check_run_id 
			and voucher_id = @voucher_id and doc_type = @doc_type and deleted = 0 

	if @doc_type = 'EOB'
		insert into #remark_table (remark, remark_type, eob_id, clinical_edit_id)
		select distinct remark, remark_type, eob_id, clinical_edit_id 
		from check_run_redcard_remark 
		where check_run_id = @check_run_id 
			and voucher_id = @voucher_id and doc_type = @doc_type and deleted = 0 and doc_id = @doc_id 

	-------------------------------------------
	-- Create EOB/EOP Remark Records
	-------------------------------------------
	select @remark_count = max(#remark_table.remark_id) from #remark_table 
	select @remark_id   = min(#remark_table.remark_id) from #remark_table 

	-- First loop: populate #remark_line_table for each unique remark
	while @remark_id <= @remark_count 
		BEGIN 
			select @remark_type = remark_type, @remark_description = remark, @eob_id = eob_id
			from #remark_table where remark_id = @remark_id 

			insert into #remark_line_table (remark_id, line_number, remark, remark_type)
			select @remark_id, line_number, remark, remark_type 
			from check_run_redcard_remark 
			where check_run_id = @check_run_id
				and voucher_id = @voucher_id and doc_type = @doc_type and deleted = 0 
				and remark = @remark_description 
				and remark_type = @remark_type and doc_id = @doc_id		-- elva 01/16/2018
				and ((eob_id = @eob_id) or (eob_id is null and @eob_id is null)) -- US#45903: keep line grouping tied to the EOB code source

			set @remark_id = @remark_id + 1
		end 

	-- Second loop: build and write remark records
	select @remark_id = min(#remark_table.remark_id) from #remark_table 

	while @remark_id <= @remark_count 
		BEGIN	

			select @remark_type = remark_type, @remark_description = remark, @eob_id = eob_id
			from #remark_table where remark_id = @remark_id 

			-- ==========================================
			-- US#45903: Get the complete EOB code from dbo.eob instead of parsing it from remark text.
			--           cRemarkCode supports up to 10 characters.
			--           Keep the original remark text unchanged in cRemarkDescription, including any
			--           EOB/remark code that is already present in the description.
			-- ==========================================
			SET @remark_code = NULL

			IF @eob_id IS NOT NULL
			BEGIN
				SELECT @remark_code = LTRIM(RTRIM(e.eob_ud))
				FROM dbo.eob e
				WHERE e.eob_id = @eob_id
			END

			-- Preserve prior behavior for remarks that do not have an EOB association
			-- (for example, a non-EOB/ACCUM remark) or if the EOB code is blank.
			IF NULLIF(LTRIM(RTRIM(@remark_code)), '') IS NULL
				SET @remark_code = '010'

			SET @clean_description = ISNULL(@remark_description, '')
			-- ==========================================

			-- 12/18/2019: ACCUM remark_type does not include line description
			-- US#45903: ACCUM path uses the original remark text; writes single record, no splitting needed
			if @remark_type = 'ACCUM'
			BEGIN
				select @line_and_remark = @clean_description + ' '

				set @recremark = '21' + @tab + '08' + @tab + @doc_id + @tab		-- AJ 41962: version 08
								+ rtrim(@remark_code) + space(10 - len(rtrim(@remark_code))) + @tab
				set @recremark = rtrim(@recremark)
								+ substring(rtrim(@line_and_remark), 1, 1200)		-- US#45903: increased from 1000 to 1200
								+ space(1200 - len(rtrim(@line_and_remark))) + @tab	-- US#45903: increased from 1000 to 1200
				set @recremark = rtrim(@recremark) + space(25) + @tab + space(4) + @tab
				set @recremark = rtrim(@recremark) + space(15) + @tab + space(100) + @tab + space(10)

				-- ============ AJ 41962: LOG TABLE — ACCUM path ============
				DECLARE @remarkcodedescTable_accum AS [dbo].[check_run_remarkcode_description_type]
				DELETE FROM @remarkcodedescTable_accum
				INSERT INTO @remarkcodedescTable_accum
				SELECT
					 '21'
					,'08'
					,ISNULL(@doc_id, '')
					,ISNULL(@remark_code, '')		-- US#45903: EOB code from dbo.eob.eob_ud (010 fallback when no EOB code)
					,ISNULL(@line_and_remark, '')	-- US#45903: description
					,'', '', '', '', '', '', '', '', '', '', ''

				SET @recremark = (SELECT TOP 1
					cRecordType + @tab + cRecordVersion + @tab + cDocId + @tab +
					cRemarkCode + @tab + cRemarkDescription + @tab + cClaimNumber + @tab +
					cLineNumber + @tab + cAmount + @tab + cRemarkDescription2 + @tab +
					cRemarkCodeType + @tab + cCARC1 + @tab + cCARC2 + @tab +
					cRARC1 + @tab + cRARC2 + @tab + cCAGC1 + @tab + cCAGC2 + @tab
				FROM @remarkcodedescTable_accum)

				EXEC [dbo].[check_run_21_remarkcodedescription_log_redcard]
					@check_run_id, @voucher_id, @doc_type, @doc_id, @remarkcodedescTable_accum

				EXEC @return_status = check_run_record_insert_redcard @check_run_id, @line_number OUTPUT, @recremark, 1, @modified_user_id
				IF @return_status <> 0
				BEGIN
					SET @error_message = 'An error in check_run_sercviceline_redcard.check_run_record_insert_redcard has occured with 106 record: ' + isnull(@record,'null')
					EXEC finance_error_log_insert @error_message, @modified_user_id
					set @email_subject = 'check_run_serviceline_redcard fatal error '
					set @email_body    = @error_message
					exec msdb.dbo.sp_send_dbmail
						@recipients = @recipients, @body = @email_body, @subject = @email_subject
					RETURN @return_status
				END
			END
			ELSE
			BEGIN
				-- ==========================================
				-- US#45903: Splitting LOGIC for non-ACCUM remarks
				--
				-- Goal: split the line number list into multiple Record 21 entries
				--       so no line numbers are ever truncated.

				SET @desc_suffix     = '; ' + @clean_description	-- original remark text (including code, if present) is appended to each chunk
				SET @available_chars = 1200 - LEN(@desc_suffix)		-- chars available for "Line [numbers]"
				SET @chunk           = 'Line'

				select @remark_line_count = max(remark_line_id) from #remark_line_table where remark_id = @remark_id 
				select @remark_line_id    = min(remark_line_id) from #remark_line_table where remark_id = @remark_id 

				while @remark_line_id <= @remark_line_count 
				BEGIN
					select @rmk_line_number = line_number 
					from #remark_line_table where remark_line_id = @remark_line_id 

					SET @is_last_line = CASE WHEN @remark_line_id = @remark_line_count THEN 1 ELSE 0 END

					-- Build this line number token: " 181," or " 181" (no comma on last)
					SET @chunk_line_part = ' ' + CONVERT(varchar(4), @rmk_line_number)
										+ CASE WHEN @is_last_line = 0 THEN ',' ELSE '' END

					IF LEN(@chunk) + LEN(@chunk_line_part) > @available_chars
					BEGIN
						-- Chunk is full — close it and write a Record 21
						SET @line_and_remark = @chunk + @desc_suffix + ' '

						set @recremark = '21' + @tab + '08' + @tab + @doc_id + @tab	-- AJ 41962: version 08
										+ rtrim(@remark_code) + space(10 - len(rtrim(@remark_code))) + @tab
						set @recremark = rtrim(@recremark)
										+ substring(rtrim(@line_and_remark), 1, 1200)		-- US#45903
										+ space(1200 - len(rtrim(@line_and_remark))) + @tab	-- US#45903
						set @recremark = rtrim(@recremark) + space(25) + @tab + space(4) + @tab
						set @recremark = rtrim(@recremark) + space(15) + @tab + space(100) + @tab + space(10)

	-- ============ INSERT FIELDS INTO REMARKCODE DESCRIPTION LOG TABLE ============ --AJ 41962 06/15/2026
	DECLARE @remarkcodedescTable AS [dbo].[check_run_remarkcode_description_type]
	DELETE FROM @remarkcodedescTable
	INSERT INTO @remarkcodedescTable                                                      
    SELECT  
		 '21'	                          -- cRecordType                                             
		,'08'                             -- cRecordVersion					
		,ISNULL(@doc_id, '')	          -- cDocId			
		,ISNULL(@remark_code, '')		  -- cRemarkCode			
		,ISNULL(@line_and_remark, '')	  -- cRemarkDescription			
		,''								  -- cClaimNumber		
		,''								  -- cLineNumber		
		,''	                              -- cAmount						
		,''	                              -- cRemarkDescription2	
		,''	                              -- cRemarkCodeType	
		,''	                              -- cCARC1	
		,''	                              -- cCARC2	
		,''	                              -- cRARC1	
		,''	                              -- cRARC2	
		,''	                              -- cCAGC1	
		,''	                              -- cCAGC2	

		SET @recremark = (SELECT TOP 1
		cRecordType             + @tab +
		cRecordVersion		    + @tab +
		cDocId				    + @tab +
		cRemarkCode			    + @tab +
		cRemarkDescription	    + @tab +
		cClaimNumber		    + @tab +	
		cLineNumber			    + @tab +
		cAmount				    + @tab +
		cRemarkDescription2	    + @tab +
		cRemarkCodeType		    + @tab +
		cCARC1				    + @tab +
		cCARC2				    + @tab +
		cRARC1				    + @tab +
		cRARC2				    + @tab +
		cCAGC1				    + @tab +
		cCAGC2				    + @tab 
	FROM @remarkcodedescTable
	)

						
	-- Save data fields and check run parameters 
	EXEC [dbo].[check_run_21_remarkcodedescription_log_redcard]
	@check_run_id,
	@voucher_id,           
	@doc_type,   
	@doc_id,  
	@remarkcodedescTable
	-- Save record to check run batch
	EXEC @return_status = check_run_record_insert_redcard @check_run_id, @line_number OUTPUT, @recremark, 1, @modified_user_id
		IF @return_status <> 0
		BEGIN
			SET @error_message = 'An error in check_run_sercviceline_redcard.check_run_record_insert_redcard has occured with 106 record: ' + isnull(@record,'null')
			EXEC finance_error_log_insert @error_message, @modified_user_id
			set @email_subject = 'check_run_serviceline_redcard fatal error '
			set @email_body    = @error_message
			exec msdb.dbo.sp_send_dbmail
				@recipients = @recipients, @body = @email_body, @subject = @email_subject
			RETURN @return_status
		END

		-- Start a new chunk with this line number
		SET @chunk = 'Line' + @chunk_line_part
		END
		ELSE
		BEGIN
			-- Line number fits in current chunk — add it
			SET @chunk = @chunk + @chunk_line_part
		END

		set @remark_line_id = @remark_line_id + 1
		END
		-- End line number loop

		-- Write the final (or only) chunk for this remark
		SET @line_and_remark = @chunk + @desc_suffix + ' '

		set @recremark = '21' + @tab + '08' + @tab + @doc_id + @tab		-- AJ 41962: version 08
						+ rtrim(@remark_code) + space(10 - len(rtrim(@remark_code))) + @tab
		set @recremark = rtrim(@recremark)
						+ substring(rtrim(@line_and_remark), 1, 1200)		-- US#45903
						+ space(1200 - len(rtrim(@line_and_remark))) + @tab	-- US#45903
		set @recremark = rtrim(@recremark) + space(25) + @tab + space(4) + @tab
		set @recremark = rtrim(@recremark) + space(15) + @tab + space(100) + @tab + space(10)

		-- ============ AJ 41962: LOG TABLE — final chunk ============
		DECLARE @remarkcodedescTable_final AS [dbo].[check_run_remarkcode_description_type]
		DELETE FROM @remarkcodedescTable_final
		INSERT INTO @remarkcodedescTable_final
		SELECT
				'21'
			,'08'
			,ISNULL(@doc_id, '')
			,ISNULL(@remark_code, '')		-- US#45903: EOB code from dbo.eob.eob_ud
			,ISNULL(@line_and_remark, '')	-- US#45903: final chunk line list + description
			,'', '', '', '', '', '', '', '', '', '', ''

		SET @recremark = (SELECT TOP 1
			cRecordType + @tab + cRecordVersion + @tab + cDocId + @tab +
			cRemarkCode + @tab + cRemarkDescription + @tab + cClaimNumber + @tab +
			cLineNumber + @tab + cAmount + @tab + cRemarkDescription2 + @tab +
			cRemarkCodeType + @tab + cCARC1 + @tab + cCARC2 + @tab +
			cRARC1 + @tab + cRARC2 + @tab + cCAGC1 + @tab + cCAGC2 + @tab
		FROM @remarkcodedescTable_final)

		select * from @remarkcodedescTable_final;

		EXEC [dbo].[check_run_21_remarkcodedescription_log_redcard]
			@check_run_id, @voucher_id, @doc_type, @doc_id, @remarkcodedescTable_final

		EXEC @return_status = check_run_record_insert_redcard @check_run_id, @line_number OUTPUT, @recremark, 1, @modified_user_id

		IF @return_status <> 0
		BEGIN
			SET @error_message = 'An error in check_run_sercviceline_redcard.check_run_record_insert_redcard has occured with 106 record: ' + isnull(@record,'null')
			EXEC finance_error_log_insert @error_message, @modified_user_id
			set @email_subject = 'check_run_serviceline_redcard fatal error '
			set @email_body    = @error_message
			exec msdb.dbo.sp_send_dbmail
				@recipients = @recipients, @body = @email_body, @subject = @email_subject
			RETURN @return_status
		END
				-- ==========================================
				-- End US#45903 splitting logic
				-- ==========================================
		END -- end non-ACCUM branch

		set @remark_id = @remark_id + 1
	END
	-- End second remark loop

	-- all the claim procedure/service lines are written, we will not write the total. Redcard will calculate it.
end try
begin catch
PRINT ERROR_MESSAGE()
	set @error_message = @error_message + 'Error in step ' + ': Error number ' + cast(error_number() as varchar) +
		' at line ' + cast(error_line() as varchar) + ': ' + error_message()
	set @return_status = -1 
	set @email_subject = 'check_run_remarkcodedescription_redcard'
	set @email_body    = @error_message
		--set @return_message = 'The following source directory is missing. "' + coalesce(@source_directory_path, '') + '"'
	exec msdb.dbo.sp_send_dbmail
		@recipients = @recipients,
		@body       = @email_body,
		@subject    = @email_subject
	return @return_status 
end catch
