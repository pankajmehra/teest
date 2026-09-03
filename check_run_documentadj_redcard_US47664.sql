USE [mcr_dc_prod]
GO
/****** Object:  StoredProcedure [dbo].[check_run_documentadj_redcard]    Script Date: 8/27/2026 7:32:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[check_run_documentadj_redcard]
    @check_run_id INT,
    @voucher_id INT,
    @doc_type CHAR(3),
    @doc_id CHAR(25),
    @claim_id INT,
    @claim_ud VARCHAR(25),
    @claim_sequence INT OUTPUT,
    @servicelinesequence INT OUTPUT,
    @line_number INT OUTPUT
AS
/*************************************************************************
Name:			[dbo].[check_run_documentadj_redcard]
Description:	Adds service line adjustment line if there is an claim_overpayment record we can net against this claim   
Used by:		Check Run Process 
Test harness:	EXEC [dbo].[check_run_documentadj_redcard] 
                     @check_run_id = 123456,
                     @claim_id = 101300807,
                     @claim_ud = '02032025E000015',
                     @doc_id = '1085001FL2025020301000001',
                     @claim_sequence = 1,
                     @servicelinesequence = 0,
                     @line_number = 0

Created:        02/01/2025 PS 39579
Modified:		10/07/2025 SP 42898 adding support for Availity claim procedure statuses
                11/13/2025 PS 43839 updating claim_overpayment.outstanding_amount when an OP transaction is processed
                01/15/2026 PS 44746 adding same bank account check for OP and donor claims  
                06/24/2026 PS 46972 creating documentadjustment record for claim reversals
                07/23/2026	KDW 	47355   query optimization for adjustment 
                09/02/2026 PM      47664   Add PLB document adjustment for PayMore/PaySame corrected claims
**************************************************************************/
BEGIN

    SET NOCOUNT ON;

    DECLARE @user_id INT;
    DECLARE @start INT;
    DECLARE @login_name VARCHAR(50);

    SELECT @start = CHARINDEX('\', SUSER_SNAME());
    SELECT @login_name = SUBSTRING(SUSER_SNAME(), @start + 1, LEN(SUSER_SNAME()) - @start);
    SELECT @user_id = [sec_user_id]
    FROM [dbo].[sec_user]
    WHERE [login_name] = @login_name;
    SELECT @user_id = ISNULL(@user_id, 0); --system 

    DECLARE @sp_name VARCHAR(100) =
            (
                SELECT OBJECT_NAME(@@PROCID)
            );
    DECLARE @error_message NVARCHAR(MAX);
    DECLARE @return_status INT = 0;

    --========== GENERAL ==========
    DECLARE @claim_net_amount MONEY = 0;
    DECLARE @claim_vendor_id INT;
    DECLARE @claim_vendor_ud VARCHAR(35);
    DECLARE @claim_bank_account_id INT;
    DECLARE @donor_claim_id INT = @claim_id;
    DECLARE @donor_claim_net_amount MONEY;
    DECLARE @claim_overpayment_id INT;
    DECLARE @overpayment_amount MONEY;
    DECLARE @overpayment_transaction_amount MONEY;
    DECLARE @overpayment_claim_id INT;
    DECLARE @overpayment_claim_ud VARCHAR(50);
    DECLARE @overpayment_eligibility_ud VARCHAR(50);
    DECLARE @overpayment_claim_procedure_id INT;
    DECLARE @overpayment_revision_number INT;
    DECLARE @overpayment_corrected_claim_id INT;
    DECLARE @fadj_offset_corrected_claim_id INT;
    DECLARE @fadj_offset_amount MONEY;
    DECLARE @overpayment_closed BIT;
    DECLARE @claim_2400_REF_6R VARCHAR(50);
    DECLARE @checkbook_check_amount MONEY;
    DECLARE @checkbook_check_netted_amount MONEY = 0;
    DECLARE @vendor_tax_id VARCHAR(20);
    DECLARE @ccx_vendor_tax_id VARCHAR(20) = '113454103'; -- CCX Real Tax ID: 113454103
    DECLARE @claim_procedure_status_id INT =
            (
                SELECT [claim_procedure_status_id]
                FROM [claim_procedure_status]
                WHERE [claim_procedure_status_ud] = 'FADJ NET REFUND'
            );
    DECLARE @donor_employergroup_client_classification_type_id INT;
    DECLARE @enable_ccx_op BIT = 0;
    DECLARE @added_by VARCHAR(50);

    --========== NETTING CONFIGURATION ==========
    DECLARE @netting_transaction_type_id INT = 2; -- Transaction type = Recovery
    DECLARE @netting_waiting_days INT = 45; -- Claims can't be netter before waiting period 
    DECLARE @netting_procedure_code_ud VARCHAR(10) = '99999'; -- cOriginalProcedureCode
    DECLARE @netting_adjustment_group_code VARCHAR(2) = 'CO'; -- cAdjustmentGroupCode 
    DECLARE @netting_carc VARCHAR(5) = '129'; -- cAdjustmentReasonCode
    DECLARE @netting_rarc VARCHAR(5) = 'N199'; -- cSvcRARC
    DECLARE @netting_eob_ud VARCHAR(50) = 'CO129'; -- cOpenField1
    DECLARE @netting_eob_nm VARCHAR(50) = ''; -- cOpenField2
    DECLARE @netting_remark VARCHAR(50) = 'Netting Applied - ';

    --========== Payment File Record Strings ==========
    DECLARE @record VARCHAR(MAX);
    DECLARE @docAdjRecord CHAR(648);
    DECLARE @RecordId INT;
    DECLARE @cRecorId INT;
    DECLARE @tab CHAR = CHAR(9);
    DECLARE @servicelinenumber INT;
    DECLARE @claim_sequence_char CHAR(6);
    DECLARE @servicelinesequence_char CHAR(6);
    DECLARE @servicelinenumber_char CHAR(3);
    DECLARE @claimrelationship_char CHAR(50);
    DECLARE @adj_amount_char CHAR(15);

    --========== DocumentAdjustment Record Fields ==========    
    DECLARE @cRecordType CHAR(2) = '45';
    DECLARE @cRecordVersion CHAR(2) = '01';
    DECLARE @cAdjustmentReasonCode CHAR(2) = 'WO';
    DECLARE @cAdjustmentDescription CHAR(100) = 'Overpayment Recovery';
    DECLARE @cAdjustmentId CHAR(50) = LEFT(@claim_ud, 15);
    DECLARE @cFiscalPeriodDate CHAR(8) = CONCAT(YEAR(GETDATE()), '12', '31');
    DECLARE @cProviderId CHAR(50);
    DECLARE @cAdjustmentAmount CHAR(15);
    DECLARE @cAdjustmentPatientAccountNumber CHAR(40);
    DECLARE @cAdjustmentGroupCode CHAR(50);
    DECLARE @cAdjustmentSubNumber CHAR(50);
    DECLARE @cAdjustmentClaimNumber CHAR(50) = @claim_ud;
    DECLARE @cAdjustmentFromServiceDate CHAR(8);
    DECLARE @cAdjustmentToServiceDate CHAR(8);


    --========== TEMP TABLES ==========
    DECLARE @Overpayment_ClaimNonDetail AS [dbo].[check_run_01_claimnondetail_type];
    DECLARE @Overpayment_ServiceLine AS [dbo].[check_run_02_serviceline_type];
    DECLARE @Overpayment_ServiceLineAdjustments AS [dbo].[check_run_32_ServiceLineAdjustments_type];
    DECLARE @documentAdjustmentTable AS [dbo].[check_run_45_documentadj_type];
    DELETE FROM @documentAdjustmentTable;

	---47355 create temp table for claim_procedure values
    DROP TABLE IF EXISTS [#claim_procedure];

    CREATE TABLE [#claim_procedure]
    (
        [claim_id] INT,
        [claim_procedure_id] INT,
        [claim_procedure_status_id] INT
    );

    BEGIN TRY

        -- Get vendor_tax_id, check amount from voucher 
        SELECT @checkbook_check_amount = ISNULL([cc].[amount], 0),
               @vendor_tax_id = [ve].[tax_id]
        FROM [dbo].[voucher] [v]
            INNER JOIN [dbo].[voucher_payment] [vp]
                ON [vp].[voucher_id] = [v].[voucher_id]
            INNER JOIN [dbo].[vendor] [ve]
                ON [ve].[vendor_id] = [v].[vendor_id]
            LEFT JOIN [dbo].[checkbook_check] [cc]
                ON [vp].[checkbook_check_id] = [cc].[checkbook_check_id]
        WHERE [v].[voucher_id] = @voucher_id;

        -- Get Employergroup and Vendor information for this claim
        SELECT TOP 1
               @claim_vendor_id = [ve].[vendor_id],
               @claim_vendor_ud = LTRIM([ve].[vendor_ud]),
               @claim_bank_account_id = [cb].[bank_account_id],
               @donor_employergroup_client_classification_type_id = [eg].[employergroup_client_classification_type_id],
               @added_by = [cfsm].[added_by]
        FROM [dbo].[claim] [c]
            INNER JOIN [dbo].[claim_procedure] [cp]
                ON [cp].[claim_id] = [c].[claim_id]
            INNER JOIN [dbo].[voucher_claim_procedure_map] [vc]
                ON [vc].[claim_procedure_id] = [cp].[claim_procedure_id]
            INNER JOIN [dbo].[voucher] [v]
                ON [v].[voucher_id] = [vc].[voucher_id]
            INNER JOIN [dbo].[checkbook] [cb]
                ON [cb].[checkbook_id] = [v].[checkbook_id]
            INNER JOIN [dbo].[eligibility] [e]
                ON [e].[eligibility_id] = [c].[eligibility_id]
            INNER JOIN [dbo].[employergroup] [eg]
                ON [eg].[employergroup_id] = [e].[employergroup_id]
            INNER JOIN [dbo].[vendor] [ve]
                ON [ve].[vendor_id] = [c].[vendor_id]
            LEFT JOIN [dbo].[claim_file_source_map] [cfsm]
                ON [cfsm].[claim_id] = [c].[claim_id]
        WHERE [c].[claim_id] = @donor_claim_id;


        -- Get Net Amount for this claim  
        SELECT @claim_net_amount = SUM([cpb].[net_amount])
        FROM [dbo].[claim_procedure] [cp]
            INNER JOIN [dbo].[claim_procedure_benefit] [cpb]
                ON [cpb].[claim_procedure_id] = [cp].[claim_procedure_id]
        WHERE [cp].[claim_id] = @claim_id
              AND [cpb].[deleted] = 0;

			  --47355 add #claim_procedure table for optimization
			INSERT INTO [#claim_procedure]
			(
				[claim_id],
				[claim_procedure_id],
				[claim_procedure_status_id]
			)
			SELECT [cp].[claim_id],
				   [cp].[claim_procedure_id],
				   [cp].[claim_procedure_status_id]
			FROM [claim_procedure] [cp]
			WHERE [claim_id] = @claim_id;

        -- 47664 PayMore/PaySame corrected claims:
        -- FADJOFFSET contains the previously paid amount that must be represented through PLB.
        SELECT @fadj_offset_corrected_claim_id = [c].[claim_id],
               @fadj_offset_amount = SUM(ISNULL([cpb].[net_amount], 0))
        FROM [dbo].[claim] [c]
            INNER JOIN [dbo].[claim_procedure] [cp47664]
                ON [cp47664].[claim_id] = [c].[claim_id]
            INNER JOIN [dbo].[claim_procedure_benefit] [cpb]
                ON [cpb].[claim_procedure_id] = [cp47664].[claim_procedure_id]
            INNER JOIN [dbo].[claim_procedure_eob] [cpe47664]
                ON [cpe47664].[claim_procedure_id] = [cp47664].[claim_procedure_id]
        WHERE [c].[claim_id] = @claim_id
              AND [c].[revision_number] > 0
              AND [cpb].[deleted] = 0
              AND [cpe47664].[eob_id] = 1977 -- FADJOFFSET
        GROUP BY [c].[claim_id];

        -- Check if this claim an overpayment corrected claim
        SELECT TOP 1
               @overpayment_corrected_claim_id = [c].[claim_id],
               @cAdjustmentId = LEFT([cpe].[additional_information], 50)
        FROM [dbo].[claim] [c]
            INNER JOIN [#claim_procedure] AS [cp]
			ON [cp].[claim_id] = [c].[claim_id]
            INNER JOIN [dbo].[claim_procedure_status] [cps]
                ON [cps].[claim_procedure_status_id] = [cp].[claim_procedure_status_id]
            INNER JOIN [dbo].[claim_procedure_eob] [cpe]
                ON [cpe].[claim_procedure_id] = [cp].[claim_procedure_id]
            INNER JOIN [dbo].[eob]
                ON [eob].[eob_id] = [cpe].[eob_id]
            INNER JOIN [dbo].[claim] [op]
                ON [op].[claim_ud] = [c].[claim_ud]
            INNER JOIN [dbo].[claim_overpayment] [co]
                ON [co].[claim_id] = [op].[claim_id]
        WHERE [c].[claim_id] = @claim_id
              AND [c].[revision_number] > [op].[revision_number]
              AND [cps].[claim_procedure_status_ud] IN ( 'FADJ REFUND', 'FADJ NET REFUND' )
              AND [eob].[eob_ud] = 'F01'
              AND [cpe].[additional_information] IS NOT NULL
        ORDER BY [cp].[claim_procedure_id];

        --SELECT @claim_id '@claim_id', @claim_ud '@claim_ud', @overpayment_corrected_claim_id '@overpayment_corrected_claim_id', @cAdjustmentId '@cAdjustmentId', @claim_net_amount '@claim_net_amount'

        -- 47664 DocumentAdjustment records are EOP-only.
        -- PaySame can have a $0 net payment and still requires a PLB entry.
        IF @doc_type <> 'EOP'
            RETURN;

        IF ISNULL(@claim_net_amount, 0) = 0
           AND @fadj_offset_corrected_claim_id IS NULL
            RETURN;


        -- ========== 47664 Create Document Adjustment Record for PayMore / PaySame Corrected Claims ==========
        IF @fadj_offset_corrected_claim_id IS NOT NULL
           AND ISNULL(@fadj_offset_amount, 0) <> 0
        BEGIN

            -- FADJOFFSET is the previously paid amount. Report it as PLB/DocumentAdjustment (CS).
            SET @cProviderId = @vendor_tax_id;
            SET @cAdjustmentReasonCode = 'CS';
            SET @cAdjustmentDescription = 'Adjustment';
            SET @cAdjustmentId = LEFT(@claim_ud, 15);
            SET @cAdjustmentAmount = CONVERT(VARCHAR(15), @fadj_offset_amount);


            INSERT INTO @documentAdjustmentTable
            (
                [cRecordType],
                [cRecordVersion],
                [cDocId],
                [cProviderId],
                [cAdjustmentReasonCode],
                [cAdjustmentDescription],
                [cAdjustmentId],
                [cAdjustmentAmount],
                [cAdjustmentClaimNumber],
                [cFiscalPeriodDate]
            )
            VALUES
            (@cRecordType, @cRecordVersion, @doc_id, @cProviderId, @cAdjustmentReasonCode, @cAdjustmentDescription,
             @cAdjustmentId, @cAdjustmentAmount, @cAdjustmentClaimNumber, @cFiscalPeriodDate);


            SET @docAdjRecord =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cProviderId] + @tab
                       + [cFiscalPeriodDate] + @tab + [cAdjustmentReasonCode] + @tab + [cAdjustmentDescription] + @tab
                       + [cAdjustmentId] + @tab + [cAdjustmentAmount] + @tab + [cAdjustmentPatientName] + @tab
                       + [cAdjustmentPatientFirstName] + @tab + [cAdjustmentPatientMiddleName] + @tab
                       + [cAdjustmentPatientLastName] + @tab + [cAdjustmentPatientAccountNumber] + @tab
                       + [cAdjustmentGroupCode] + @tab + [cAdjustmentSubNumber] + @tab + [cAdjustmentClaimNumber] + @tab
                       + [cAdjustmentFromServiceDate] + @tab + [cAdjustmentToServiceDate]
                FROM @documentAdjustmentTable
            );


            IF @docAdjRecord IS NOT NULL
            BEGIN
                EXEC [dbo].[check_run_45_documentadj_log_redcard] @check_run_id,
                                                                  @voucher_id,
                                                                  @doc_type,
                                                                  @doc_id,
                                                                  @donor_claim_id,
                                                                  @claim_ud,
                                                                  @documentAdjustmentTable;

                EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id,
                                                                              @line_number OUTPUT,
                                                                              @docAdjRecord,
                                                                              1,
                                                                              @user_id;
            END;

        END;
        -- ========== Create Document Adjustment Record for OP Corrected Claims / PayLess ==========
        ELSE IF @overpayment_corrected_claim_id IS NOT NULL
           AND @cAdjustmentId IS NOT NULL
        BEGIN

            -- Set Adjustment Fields 
            SET @cProviderId = @vendor_tax_id;
            SET @cAdjustmentReasonCode = 'WO';
            SET @cAdjustmentDescription = 'Overpayment Recovery';
            SET @cAdjustmentAmount = CONVERT(VARCHAR(15), @claim_net_amount);


            INSERT INTO @documentAdjustmentTable
            (
                [cRecordType],
                [cRecordVersion],
                [cDocId],
                [cProviderId],
                [cAdjustmentReasonCode],
                [cAdjustmentDescription],
                [cAdjustmentId],
                [cAdjustmentAmount],
                [cAdjustmentClaimNumber],
                [cFiscalPeriodDate]
            )
            VALUES
            (@cRecordType, @cRecordVersion, @doc_id, @cProviderId, @cAdjustmentReasonCode, @cAdjustmentDescription,
             @cAdjustmentId, @cAdjustmentAmount, @cAdjustmentClaimNumber, @cFiscalPeriodDate);


            --  INSERT DocumentAdjustment fields to Table Type 
            SET @docAdjRecord =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cProviderId] + @tab
                       + [cFiscalPeriodDate] + @tab + [cAdjustmentReasonCode] + @tab + [cAdjustmentDescription] + @tab
                       + [cAdjustmentId] + @tab + [cAdjustmentAmount] + @tab + [cAdjustmentPatientName] + @tab
                       + [cAdjustmentPatientFirstName] + @tab + [cAdjustmentPatientMiddleName] + @tab
                       + [cAdjustmentPatientLastName] + @tab + [cAdjustmentPatientAccountNumber] + @tab
                       + [cAdjustmentGroupCode] + @tab + [cAdjustmentSubNumber] + @tab + [cAdjustmentClaimNumber] + @tab
                       + [cAdjustmentFromServiceDate] + @tab + [cAdjustmentToServiceDate]
                FROM @documentAdjustmentTable
            );


            IF @docAdjRecord IS NOT NULL
            BEGIN
                -- Save documentAdjustmentTable row and check run parameters
                EXEC [dbo].[check_run_45_documentadj_log_redcard] @check_run_id,
                                                                  @voucher_id,
                                                                  @doc_type,
                                                                  @doc_id,
                                                                  @donor_claim_id,
                                                                  @claim_ud,
                                                                  @documentAdjustmentTable;

                -- Save record to check run batch
                EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id,
                                                                              @line_number OUTPUT,
                                                                              @docAdjRecord,
                                                                              1,
                                                                              @user_id;
            END;

        END;
        -- ========== Create Document Adjustment Record for Claim Negates ==========
        ELSE IF ISNULL(@added_by, '') = 'claim_negate'
        BEGIN

            -- Set Adjustment Fields 
            SET @cProviderId = @vendor_tax_id;
            SET @cAdjustmentReasonCode = 'CS';
            SET @cAdjustmentDescription = 'Adjustment';
            SET @cAdjustmentId = @claim_ud;
            SET @cAdjustmentAmount = CONVERT(VARCHAR(15), @claim_net_amount);


            INSERT INTO @documentAdjustmentTable
            (
                [cRecordType],
                [cRecordVersion],
                [cDocId],
                [cProviderId],
                [cAdjustmentReasonCode],
                [cAdjustmentDescription],
                [cAdjustmentId],
                [cAdjustmentAmount],
                [cAdjustmentClaimNumber],
                [cFiscalPeriodDate]
            )
            VALUES
            (@cRecordType, @cRecordVersion, @doc_id, @cProviderId, @cAdjustmentReasonCode, @cAdjustmentDescription,
             @cAdjustmentId, @cAdjustmentAmount, @cAdjustmentClaimNumber, @cFiscalPeriodDate);


            --  INSERT DocumentAdjustment fields to Table Type 
            SET @docAdjRecord =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cProviderId] + @tab
                       + [cFiscalPeriodDate] + @tab + [cAdjustmentReasonCode] + @tab + [cAdjustmentDescription] + @tab
                       + [cAdjustmentId] + @tab + [cAdjustmentAmount] + @tab + [cAdjustmentPatientName] + @tab
                       + [cAdjustmentPatientFirstName] + @tab + [cAdjustmentPatientMiddleName] + @tab
                       + [cAdjustmentPatientLastName] + @tab + [cAdjustmentPatientAccountNumber] + @tab
                       + [cAdjustmentGroupCode] + @tab + [cAdjustmentSubNumber] + @tab + [cAdjustmentClaimNumber] + @tab
                       + [cAdjustmentFromServiceDate] + @tab + [cAdjustmentToServiceDate]
                FROM @documentAdjustmentTable
            );


            IF @docAdjRecord IS NOT NULL
            BEGIN
                -- Save documentAdjustmentTable row and check run parameters
                EXEC [dbo].[check_run_45_documentadj_log_redcard] @check_run_id,
                                                                  @voucher_id,
                                                                  @doc_type,
                                                                  @doc_id,
                                                                  @donor_claim_id,
                                                                  @claim_ud,
                                                                  @documentAdjustmentTable;

                -- Save record to check run batch
                EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id,
                                                                              @line_number OUTPUT,
                                                                              @docAdjRecord,
                                                                              1,
                                                                              @user_id;
            END;

        END;
        -- ========== Create Document Adjustment Record for NETTING ==========
        ELSE IF @donor_employergroup_client_classification_type_id = 42 -- Only processing netting for Gatorcare
        BEGIN

            -- Get 2400_REF_6R code for this claim 
            SELECT TOP 1
                   @claim_2400_REF_6R = [r].[L2400_ref02_reference]
            FROM [claim]
                INNER JOIN [Edee].[dbo].[x12_837_2300] [c]
                    ON [c].[x12_837_2300_id] = [claim].[x12_837_2300_id]
                INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]
                    ON [c].[x12_837_2300_id] = [cp].[x12_837_2300_id]
                INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r]
                    ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
            WHERE [claim].[claim_id] = @donor_claim_id
                  AND [r].[L2400_ref01_code] = '6R'
            ORDER BY [cp].[x12_837_2400_id];

            SET @claim_2400_REF_6R = ISNULL(@claim_2400_REF_6R, '');


            -- Get Net Amount for this claim  
            SET @donor_claim_net_amount = @claim_net_amount;

            -- ==================== BEGIN NETTING PRECESSING ====================================
            -- If @donor_claim_net_amount is less than the @overpayment_amount, a partial netting transaction is created and overpayment status remains open 
            -- If @donor_claim_net_amount is equal or greater than the @overpayment_amount, a full netting transaction is created and remainder amount is used the next overpaid claim  
            WHILE @donor_claim_net_amount > 0
            BEGIN

                SET @claim_overpayment_id = NULL;
                SET @overpayment_amount = NULL;
                SET @overpayment_closed = NULL;

                -- Search in [dbo].[claim_overpayment] table for an overpaid claim that can be satisfied by this donor claim 
                SELECT TOP 1
                       @claim_overpayment_id = [co].[claim_overpayment_id],
                       @overpayment_amount = ([co].[overpayment_amount] - ISNULL([transactions].[amount], 0)),
                       @overpayment_eligibility_ud = [e].[eligibility_ud],
                       @overpayment_claim_id = [co].[claim_id],
                       @overpayment_claim_ud = [c].[claim_ud],
                       @overpayment_revision_number = [c].[revision_number],
                       @overpayment_claim_procedure_id = [co].[claim_procedure_id]
                FROM [dbo].[claim_overpayment] [co]
                    INNER JOIN [dbo].[claim] [c]
                        ON [c].[claim_id] = [co].[claim_id]
                    INNER JOIN [dbo].[eligibility] [e]
                        ON [e].[eligibility_id] = [c].[eligibility_id]
                    INNER JOIN [dbo].[employergroup] [eg]
                        ON [eg].[employergroup_id] = [e].[employergroup_id]
                    INNER JOIN [dbo].[claim_procedure] [cp]
                        ON [cp].[claim_id] = [c].[original_claim_id]
                    INNER JOIN [dbo].[voucher_claim_procedure_map] [vc]
                        ON [vc].[claim_procedure_id] = [cp].[claim_procedure_id]
                    INNER JOIN [dbo].[voucher] [v]
                        ON [v].[voucher_id] = [vc].[voucher_id]
                    INNER JOIN [dbo].[checkbook] [cb]
                        ON [cb].[checkbook_id] = [v].[checkbook_id]
                    OUTER APPLY
                (
                    SELECT SUM([amount]) [amount]
                    FROM [dbo].[claim_overpayment_transaction] [ot]
                    WHERE [ot].[claim_overpayment_id] = [co].[claim_overpayment_id]
                ) [transactions]
                    OUTER APPLY
                (
                    SELECT TOP 1
                           [tax_id]
                    FROM [vendor]
                    WHERE [vendor_id] = [co].[vendor_id]
                ) [ve]
                WHERE [co].[claim_overpayment_status_id] = 1 -- Open 
                      AND [co].[ok_to_net_indicator] = 1
                      AND [c].[claim_ud] <> @claim_ud
                      AND [eg].[employergroup_client_classification_type_id] = 42 -- Only processing netting for: FB Master Claims Account
                      AND [cb].[bank_account_id] = @claim_bank_account_id
                      AND
                      (
                          (DATEDIFF(DAY, [co].[created_date], GETDATE()) >= @netting_waiting_days)
                          OR EXISTS
                             (
                                 SELECT 1
                                 FROM [claim_procedure] [cp2]
                                 WHERE [cp2].[claim_id] = [c].[claim_id]
                                       AND [cp2].[claim_procedure_status_id] IN ( 126, 130 )
                             ) -- OVPMT PART STFD or AVL OVPMT NET to bypass WP	 
                      )
                      AND NOT EXISTS
                              (
                                  SELECT 1
                                  FROM [claim_procedure] [cp3]
                                  WHERE [cp3].[claim_id] = [c].[claim_id]
                                        AND [cp3].[claim_procedure_status_id] = 128
                              ) --42898 AVL OVPMT DSPT
                      AND [ve].[tax_id] = @vendor_tax_id
                      AND [ve].[tax_id] <> @ccx_vendor_tax_id
                ORDER BY [co].[claim_overpayment_id] ASC;

                -- ==================== BEGIN NETTING TRANSACTIONS ==============================
                IF @claim_overpayment_id IS NOT NULL
                BEGIN

                    -- PARTIAL NETTING, LOG TRANSACTION BUT OVERPAYMENT REMAINS OPEN  
                    IF @donor_claim_net_amount < @overpayment_amount
                    BEGIN

                        SET @overpayment_transaction_amount = @donor_claim_net_amount;
                        SET @donor_claim_net_amount = 0;
                    END;

                    -- FULL NETTING AND OVERPAYMENT IS CLOSED
                    ELSE IF @donor_claim_net_amount = @overpayment_amount
                    BEGIN

                        SET @overpayment_transaction_amount = @overpayment_amount;
                        SET @donor_claim_net_amount = 0;
                        SET @overpayment_closed = 1;
                    END;

                    -- FULL NETTING, LOG TRANSACTION AND OVERPAYMENT IS CLOSED
                    ELSE IF @donor_claim_net_amount > @overpayment_amount
                    BEGIN

                        SET @overpayment_transaction_amount = @overpayment_amount;
                        SET @donor_claim_net_amount = @donor_claim_net_amount - @overpayment_amount;
                        SET @overpayment_closed = 1;
                    END;


                    -- ********************************************************************************
                    -- Each netting transaction reduces the check amount to the provider. Only proceed if this  
                    -- transaction does not drive the running total for current provider payment to exceed 
                    -- the actual checkbook check amount. The check amount must always remain > $0
                    -- *********************************************************************************
                    SELECT @checkbook_check_netted_amount = SUM([ot].[amount])
                    FROM [dbo].[claim_overpayment_transaction] [ot]
                    WHERE [ot].[check_run_id] = @check_run_id
                          AND [ot].[voucher_id] = @voucher_id;

                    DECLARE @log VARCHAR(500)
                        = CONCAT(
                                    'Check Amount: ',
                                    @checkbook_check_amount,
                                    ' Netting Running: ',
                                    ISNULL(@checkbook_check_netted_amount, 0),
                                    ' Trans: ',
                                    @overpayment_transaction_amount,
                                    ' NEW SUM: ',
                                    (ISNULL(@checkbook_check_netted_amount, 0) + @overpayment_transaction_amount)
                                );
                    IF (ISNULL(@checkbook_check_netted_amount, 0) + @overpayment_transaction_amount) >= @checkbook_check_amount
                    BEGIN
                        -- Exit 
                        SET @log = @log + ' - STOP HERE';
                        PRINT @log;
                        GOTO PLB_Adjustments;
                    END;

                    SET @log = @log + ' - PASS';
                    --PRINT @log

                    -- =========== Log Transaction in [claim_overpayment_transaction] =========== 
                    INSERT INTO [dbo].[claim_overpayment_transaction]
                    (
                        [claim_overpayment_id],
                        [claim_overpayment_transaction_type_id],
                        [donor_claim_id],
                        [amount],
                        [check_run_id],
                        [voucher_id],
                        [created_user],
                        [created_date],
                        [modified_user],
                        [modified_date],
                        [deleted]
                    )
                    SELECT @claim_overpayment_id,
                           @netting_transaction_type_id,
                           @donor_claim_id,
                           @overpayment_transaction_amount,
                           @check_run_id,
                           @voucher_id,
                           @login_name,
                           GETDATE(),
                           @login_name,
                           GETDATE(),
                           0;


                    -- =========== Recalculate outstanding_amount [claim_overpayment] =========== 
                    UPDATE [co]
                    SET [co].[outstanding_amount] = [overpayment_amount]
                                                    - ISNULL(
                                                      (
                                                          SELECT SUM([t].[amount])
                                                          FROM [claim_overpayment_transaction] [t]
                                                          WHERE [t].[claim_overpayment_id] = [co].[claim_overpayment_id]
                                                      ),
                                                      0
                                                            )
                    FROM [claim_overpayment] [co]
                    WHERE [claim_overpayment_id] = @claim_overpayment_id;


                    -- Add comments to both overpaid and donor claims 
                    INSERT INTO [dbo].[claim_comment]
                    (
                        [claim_id],
                        [comment],
                        [active],
                        [created_user_id],
                        [modified_user_id],
                        [deleted],
                        [claim_comment_type_id]
                    )
                    VALUES
                    (@overpayment_claim_id,
                     CONCAT('Netting of: $', @overpayment_transaction_amount, ' from Claim: ', @donor_claim_id), 1,
                     @user_id, @user_id, 0, 1);

                    INSERT INTO [dbo].[claim_comment]
                    (
                        [claim_id],
                        [comment],
                        [active],
                        [created_user_id],
                        [modified_user_id],
                        [deleted],
                        [claim_comment_type_id]
                    )
                    VALUES
                    (@donor_claim_id,
                     CONCAT(
                               'Netting of: $',
                               @overpayment_transaction_amount,
                               ' applied on Claim: ',
                               @overpayment_claim_id
                           ), 1, @user_id, @user_id, 0, 1);


                    -- =========== Update claim_overpayment as Closed =========== 
                    IF @overpayment_closed = 1
                    BEGIN

                        -- Get Corrected Claim Id
                        SELECT TOP 1
                               @overpayment_corrected_claim_id = [c].[claim_id]
                        FROM [dbo].[claim] [c]
                            INNER JOIN [dbo].[claim_procedure] [cp]
                                ON [cp].[claim_id] = [c].[claim_id]
                            INNER JOIN [dbo].[claim_procedure_status] [cps]
                                ON [cps].[claim_procedure_status_id] = [cp].[claim_procedure_status_id]
                        WHERE [c].[claim_ud] = @overpayment_claim_ud
                              AND [c].[claim_id] > @overpayment_claim_id
                              AND [cps].[claim_procedure_status_ud] IN ( 'FADJ VD/STOPPAY', 'FADJ REFUND',
                                                                         'FADJ ADJUSTMENT', 'FADJ PRIOR CARR',
                                                                         'FADJ SUBRO REF', 'FADJ NO PAY',
                                                                         'FADJ NO CHECK', 'FADJ FC ACCUM',
                                                                         'FADJ VD/SP DENY'
                                                                       );


                        -- Approve negated and corrected claims so they can close 
                        UPDATE [dbo].[claim]
                        SET [claim_workflow_id] = 3,
                            [claim_financial_status_id] = 1
                        WHERE [claim_id] IN ( @overpayment_claim_id, @overpayment_corrected_claim_id );

                        -- Set overpayment status (closed) 
                        UPDATE [dbo].[claim_overpayment]
                        SET [claim_overpayment_status_id] = 2,
                            [outstanding_amount] = 0
                        WHERE [claim_overpayment_id] = @claim_overpayment_id;

                        -- Set claim procedure status (OVPMT NET STFD)
                        UPDATE [dbo].[claim_procedure]
                        SET [claim_procedure_status_id] = 125
                        WHERE [claim_procedure_id] = @overpayment_claim_procedure_id;

                        -- Set new claim procedure status to other FADJ adjustments on overpaid and corrected claims (FADJ NET REFUND)
                        UPDATE [cp]
                        SET [cp].[claim_procedure_status_id] = @claim_procedure_status_id
                        FROM [dbo].[claim] [c]
                            INNER JOIN [dbo].[claim_procedure] [cp]
                                ON [cp].[claim_id] = [c].[claim_id]
                            INNER JOIN [dbo].[claim_procedure_status] [cps]
                                ON [cps].[claim_procedure_status_id] = [cp].[claim_procedure_status_id]
                        WHERE [c].[claim_ud] = @overpayment_claim_ud
                              AND [c].[claim_id] >= @overpayment_claim_id
                              AND [cp].[claim_procedure_id] <> @overpayment_claim_procedure_id
                              AND [cps].[claim_procedure_status_ud] IN ( 'FADJ VD/STOPPAY', 'FADJ REFUND',
                                                                         'FADJ ADJUSTMENT', 'FADJ PRIOR CARR',
                                                                         'FADJ SUBRO REF', 'FADJ NO PAY',
                                                                         'FADJ NO CHECK', 'FADJ FC ACCUM',
                                                                         'FADJ VD/SP DENY'
                                                                       );

                    END;
                    ELSE
                    BEGIN
                        -- Set claim procedure status (OVPMT PART STFD)
                        UPDATE [dbo].[claim_procedure]
                        SET [claim_procedure_status_id] = 126
                        WHERE [claim_procedure_id] = @overpayment_claim_procedure_id;
                    END;


                    -- ======== Insert transaction into DocumentAdjustment table for PLB mapping ========
                    SET @cProviderId = @claim_vendor_ud;
                    SET @cAdjustmentAmount = CONVERT(VARCHAR(15), ISNULL(@overpayment_transaction_amount, 0));
                    SET @cAdjustmentSubNumber = CONVERT(CHAR(50), @claim_overpayment_id);
                    SET @cAdjustmentId = CONCAT(@overpayment_eligibility_ud, ' ', @overpayment_claim_ud);
                    SET @cAdjustmentPatientAccountNumber = @overpayment_eligibility_ud;

                    INSERT INTO @documentAdjustmentTable
                    (
                        [cRecordType],
                        [cRecordVersion],
                        [cDocId],
                        [cProviderId],
                        [cAdjustmentReasonCode],
                        [cAdjustmentDescription],
                        [cAdjustmentId],
                        [cAdjustmentAmount],
                        [cAdjustmentClaimNumber],
                        [cAdjustmentSubNumber],
                        [cAdjustmentPatientAccountNumber],
                        [cFiscalPeriodDate]
                    )
                    VALUES
                    (@cRecordType, @cRecordVersion, @doc_id, @cProviderId, @cAdjustmentReasonCode,
                     @cAdjustmentDescription, @cAdjustmentId, @cAdjustmentAmount, @cAdjustmentClaimNumber,
                     @cAdjustmentSubNumber, @cAdjustmentPatientAccountNumber, @cFiscalPeriodDate);



                END; -- IF @claim_overpayment_id IS NOT NULL 
                ELSE
                BEGIN
                    SET @donor_claim_net_amount = 0;
                END;

            END; -- WHILE @donor_claim_net_amount > 0

            PLB_Adjustments:


            IF EXISTS (SELECT 1 FROM @documentAdjustmentTable)
            BEGIN
                -- ===== Save all documentAdjustmentTable rows and check run parameters =====
                EXEC [dbo].[check_run_45_documentadj_log_redcard] @check_run_id,
                                                                  @voucher_id,
                                                                  @doc_type,
                                                                  @doc_id,
                                                                  @donor_claim_id,
                                                                  @claim_ud,
                                                                  @documentAdjustmentTable;


                -- ======== INSERT DocumentAdjustment Records in payment file  ========
                WHILE
                (SELECT COUNT(*)FROM @documentAdjustmentTable) > 0
                BEGIN

                    SELECT TOP 1
                           @RecordId = [cRecordId]
                    FROM @documentAdjustmentTable;

                    SET @docAdjRecord =
                    (
                        SELECT [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cProviderId] + @tab
                               + [cFiscalPeriodDate] + @tab + [cAdjustmentReasonCode] + @tab + [cAdjustmentDescription]
                               + @tab + [cAdjustmentId] + @tab + [cAdjustmentAmount] + @tab + [cAdjustmentPatientName]
                               + @tab + [cAdjustmentPatientFirstName] + @tab + [cAdjustmentPatientMiddleName] + @tab
                               + [cAdjustmentPatientLastName] + @tab + [cAdjustmentPatientAccountNumber] + @tab
                               + [cAdjustmentGroupCode] + @tab + [cAdjustmentSubNumber] + @tab
                               + [cAdjustmentClaimNumber] + @tab + [cAdjustmentFromServiceDate] + @tab
                               + [cAdjustmentToServiceDate]
                        FROM @documentAdjustmentTable
                        WHERE [cRecordId] = @RecordId
                    );

                    IF @docAdjRecord IS NOT NULL
                    BEGIN
                        -- Save record to check run batch
                        EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id,
                                                                                      @line_number OUTPUT,
                                                                                      @docAdjRecord,
                                                                                      1,
                                                                                      @user_id;
                    END;

                    -- Delete record from DocumentAdjustment Table 
                    DELETE FROM @documentAdjustmentTable
                    WHERE [cRecordId] = @RecordId;

                END; -- WHILE COUNT(*) > 0

            END; -- EXISTS @documentAdjustmentTable

        END;


    END TRY
    BEGIN CATCH

        PRINT 'ERROR';
        PRINT ERROR_MESSAGE();

    END CATCH;

END;
