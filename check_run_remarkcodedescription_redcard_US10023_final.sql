USE [mcr_dc_prod]
GO
/****** Object:  StoredProcedure [dbo].[check_run_remarkcodedescription_redcard]    Script Date: 6/15/2026 11:17:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER   PROCEDURE [dbo].[check_run_remarkcodedescription_redcard]
	@check_run_id [int],
	@modified_user_id [int],
	@voucher_id [int],
	@claim_id [int],
	@claim_ud [varCHAR] (25),
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
	cRemarkDescription			1200	-- US#10023: Updated from 1000 to 1200 to match payment file spec
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
	06/17/2026    - US#10023  - Extract real remark code from front of description text instead of hardcoding '010'
	                          - Strip remark code from description to avoid duplication in cRemarkDescription field
	                          - Raise @line_and_remark and cRemarkDescription field length from 1000 to 1200 to match payment file spec
	                          - Replace single record write with chunking logic: when line number list + description
	                            exceeds 1200 chars, split into multiple Record 21 entries each carrying the same
	                            remark code with description appended at end of each chunk — no lines truncated
	                          - Logging block (@remarkcodedescTable) updated to pass @clean_description and 
	                            real @remark_code — called inside each chunk write so every chunk is logged
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
	-- US#10023: New variables for remark code extraction
	--           @split_pos    : position of first non-numeric character in description
	--           @clean_description : description with remark code stripped from front
	-- ==========================================
	DECLARE @split_pos					INT
	DECLARE @clean_description			VARCHAR(1200)
	-- ==========================================

	-- ==========================================
	-- US#10023: New variables for chunking logic
	--           Splits line number list into multiple Record 21 entries
	--           when total length exceeds 1200 chars.
	--           Each chunk carries the same remark code and description at end.
	-- ==========================================
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
	-- US#10023: Raised @line_and_remark from varchar(1000) to varchar(1200)
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
			select @remark_type = remark_type, @remark_description = remark 
			from #remark_table where remark_id = @remark_id 

			insert into #remark_line_table (remark_id, line_number, remark, remark_type)
			select @remark_id, line_number, remark, remark_type 
			from check_run_redcard_remark 
			where check_run_id = @check_run_id
				and voucher_id = @voucher_id and doc_type = @doc_type and deleted = 0 
				and remark = @remark_description 
				and remark_type = @remark_type and doc_id = @doc_id		-- elva 01/16/2018

			set @remark_id = @remark_id + 1
		end 

	-- Second loop: build and write remark records
	select @remark_id = min(#remark_table.remark_id) from #remark_table 

	while @remark_id <= @remark_count 
		BEGIN	

			select @remark_type = remark_type, @remark_description = remark 
			from #remark_table where remark_id = @remark_id 

			-- ==========================================
			-- US#10023: Extract real remark code from front of description
			--           Descriptions stored as e.g. '02PROC INELIGIBLE...' or '053 FEE SCHEDULE...'
			--           PATINDEX finds position of first non-numeric character
			--           Everything before it = remark code
			--           Everything after it  = clean description (no code prefix)
			-- ==========================================
			SET @split_pos = PATINDEX('%[^0-9]%', LTRIM(@remark_description))

			IF @split_pos > 1
			BEGIN
				-- Numeric prefix found: extract as remark code, strip from description
				SET @remark_code       = LEFT(LTRIM(@remark_description), @split_pos - 1)
				SET @clean_description = LTRIM(SUBSTRING(LTRIM(@remark_description), @split_pos, LEN(@remark_description)))
			END
			ELSE
			BEGIN
				-- No numeric prefix found: fall back to '010', use description as-is
				SET @remark_code       = '010'
				SET @clean_description = LTRIM(@remark_description)
			END
			-- ==========================================

			-- 12/18/2019: ACCUM remark_type does not include line description
			-- US#10023: ACCUM path uses @clean_description; writes single record, no chunking needed
			if @remark_type = 'ACCUM'
			BEGIN
				select @line_and_remark = @clean_description + ' '

				set @recremark = '21' + @tab + '08' + @tab + @doc_id + @tab		-- AJ 41962: version 08
								+ rtrim(@remark_code) + space(10 - len(rtrim(@remark_code))) + @tab
				set @recremark = rtrim(@recremark)
								+ substring(rtrim(@line_and_remark), 1, 1200)		-- US#10023: raised from 1000 to 1200
								+ space(1200 - len(rtrim(@line_and_remark))) + @tab	-- US#10023: raised from 1000 to 1200
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
					,ISNULL(@remark_code, '')		-- US#10023: real remark code, not '010'
					,ISNULL(@line_and_remark, '')	-- US#10023: clean description
					,'', '', '', '', '', '', '', '', '', '', ''

				SET @recremark = (SELECT TOP 1
					cRecordType + @tab + cRecordVersion + @tab + cDocId + @tab +
					cRemarkCode + @tab + cRemarkDescription + @tab + cClaimNumber + @tab +
					cLineNumber + @tab + cAmount + @tab + cRemarkDescription2 + @tab +
					cRemarkCodeType + @tab + cCARC1 + @tab + cCARC2 + @tab +
					cRARC1 + @tab + cRARC2 + @tab + cCAGC1 + @tab + cCAGC2 + @tab
				FROM @remarkcodedescTable_accum)

				EXEC [dbo].[check_run_21_remarkcodedescription_log_redcard]
					@check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @remarkcodedescTable_accum

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
				-- US#10023: CHUNKING LOGIC for non-ACCUM remarks
				--
				-- Goal: split the line number list into multiple Record 21 entries
				--       so no line numbers are ever truncated.
				--
				-- Each Record 21 chunk:
				--   - Starts with "Line [line numbers]"
				--   - Ends with   "; [clean description]"
				--   - Total length does not exceed 1200 chars
				--   - Carries the real remark code in cRemarkCode
				--   - Is logged via @remarkcodedescTable (AJ 41962) — one log entry per chunk
				--
				-- How it works:
				--   1. Build @desc_suffix = "; " + clean description
				--   2. @available_chars  = 1200 - LEN(@desc_suffix)
				--      This is how many chars are left for "Line [numbers]"
				--   3. Loop through each line number for this remark
				--   4. If adding next number would exceed @available_chars:
				--        - Close current chunk: append @desc_suffix, write Record 21 + log
				--        - Start new chunk with "Line [this number]"
				--   5. After loop: write the final chunk
				-- ==========================================

				SET @desc_suffix     = '; ' + @clean_description	-- e.g. "; PROC INELIGIBLE PROCEDURE CODES"
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
										+ substring(rtrim(@line_and_remark), 1, 1200)		-- US#10023
										+ space(1200 - len(rtrim(@line_and_remark))) + @tab	-- US#10023
						set @recremark = rtrim(@recremark) + space(25) + @tab + space(4) + @tab
						set @recremark = rtrim(@recremark) + space(15) + @tab + space(100) + @tab + space(10)

						-- ============ AJ 41962: LOG TABLE — one entry per chunk ============
						DECLARE @remarkcodedescTable AS [dbo].[check_run_remarkcode_description_type]
						DELETE FROM @remarkcodedescTable
						INSERT INTO @remarkcodedescTable
						SELECT
							 '21'
							,'08'
							,ISNULL(@doc_id, '')
							,ISNULL(@remark_code, '')		-- US#10023: real remark code
							,ISNULL(@line_and_remark, '')	-- US#10023: this chunk's line list + description
							,'', '', '', '', '', '', '', '', '', '', ''

						SET @recremark = (SELECT TOP 1
							cRecordType + @tab + cRecordVersion + @tab + cDocId + @tab +
							cRemarkCode + @tab + cRemarkDescription + @tab + cClaimNumber + @tab +
							cLineNumber + @tab + cAmount + @tab + cRemarkDescription2 + @tab +
							cRemarkCodeType + @tab + cCARC1 + @tab + cCARC2 + @tab +
							cRARC1 + @tab + cRARC2 + @tab + cCAGC1 + @tab + cCAGC2 + @tab
						FROM @remarkcodedescTable)

						EXEC [dbo].[check_run_21_remarkcodedescription_log_redcard]
							@check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @remarkcodedescTable

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
								+ substring(rtrim(@line_and_remark), 1, 1200)		-- US#10023
								+ space(1200 - len(rtrim(@line_and_remark))) + @tab	-- US#10023
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
					,ISNULL(@remark_code, '')		-- US#10023: real remark code
					,ISNULL(@line_and_remark, '')	-- US#10023: final chunk line list + description
					,'', '', '', '', '', '', '', '', '', '', ''

				SET @recremark = (SELECT TOP 1
					cRecordType + @tab + cRecordVersion + @tab + cDocId + @tab +
					cRemarkCode + @tab + cRemarkDescription + @tab + cClaimNumber + @tab +
					cLineNumber + @tab + cAmount + @tab + cRemarkDescription2 + @tab +
					cRemarkCodeType + @tab + cCARC1 + @tab + cCARC2 + @tab +
					cRARC1 + @tab + cRARC2 + @tab + cCAGC1 + @tab + cCAGC2 + @tab
				FROM @remarkcodedescTable_final)

				EXEC [dbo].[check_run_21_remarkcodedescription_log_redcard]
					@check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @remarkcodedescTable_final

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
				-- End US#10023 chunking logic
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
	exec msdb.dbo.sp_send_dbmail
		@recipients = @recipients,
		@body       = @email_body,
		@subject    = @email_subject
	return @return_status 
end catch
