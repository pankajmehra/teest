USE [mcr_dc_prod]
GO
/****** Object:  StoredProcedure [dbo].[check_run_servicelineadj835_redcard ]    Script Date: 8/27/2026 7:29:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[check_run_servicelineadj835_redcard ]
    @check_run_id [INT],
    @modified_user_id [INT],
    @voucher_id [INT],
    @claim_id [INT],
    @claim_ud [VARCHAR](25),
    @doc_type [CHAR](5),
    @doc_id [CHAR](25),
    @suppress_eop BIT,
    @claim_sequence INT,
    @servicelinesequence INT, -- the serviceline number within the eob/eop   
    @line_number [INT] OUTPUT -- line number in the @record table   


WITH EXECUTE AS CALLER
AS
/** ---------------------------------------------------------------------------------------------------------  
  called from check_run_claimnondetail_redcard to generate the servicelineadj835 records ,   
  The servicelineAdjustments records which are used for the 835 information   
  These are all tab delimited files  
   
 ServiceLine   
 cRecordType     2 Always 32  
 cRecordVersion    2 21  
 cDocId      25  
 cClaimSequence    6  
 cClaimNumber    25  
 cServiceLineSequence  6  the count of the service lines on the claim procedrue  
 cLineNumber     3  Service Line Number line number of claim procedure within claim claim_line_sequence  
 cClaimRelationString  50  Claim Relationship - Used to tie multiple records for the same Claim together  
 cLabel      25  adjustment lable  
 cServiceQualifier   2  Service Qualifier id  
 cAdjustmentAmount   15  Service Line Adjustment Amount  
 cAdjustmentGroupCode  2  Service Line Adjustment Group Code  
 cAdjustmentReasonCode  5  Service Line Adjustment Reason Code (CARC)  
 cSvcRARC     5  Service Line Remittance Advice Remark Code (RARC)  
 cLineItemControlNumber  50  Service Line Item Control Number from 837  
 cOriginalProcedureCode  10  Original Procedure Code  
 cAlternateProcedureCode  15  Alternate procedure code for institutional claims with a DRG code  
 cOpenField1     50  Open Text Field #1  
 cOpenField2     50  Open Text Field #2  
 cOpenField3     50  Open Text Field #3  
 cOriginalChargeAmount  15  Original amount charged  
 cOriginalLineNumber   15  Original Service Line Number  
 cOriginalUnits    10  Original number of units rendered  

 ----------------------------------------------------------------------------------------------------------------------------------------------
 To get values:
 SELECT [v].[check_run_id], 3339, [v].[voucher_id], [c].[claim_id], [c].[claim_ud],
'eop', 'testing_835', 0,1,1,1

FROM [dbo].[claim] AS [c]
INNER JOIN [dbo].[claim_procedure] AS [cp]
ON [cp].[claim_id] = [c].[claim_id]
INNER JOIN [dbo].[voucher_claim_procedure_map] AS [vcpm]
ON [vcpm].[claim_procedure_id] = [cp].[claim_procedure_id]
INNER JOIN [dbo].[voucher] AS [v]
ON [v].[voucher_id] = [vcpm].[voucher_id]
WHERE [c].[claim_ud] = '11072025E009436'

 
 DECLARE @check_run_id [INT];
DECLARE @modified_user_id [INT];
DECLARE @voucher_id [INT];
DECLARE @claim_id [INT];
DECLARE @claim_ud [VARCHAR](25);
DECLARE @doc_type [CHAR](5);
DECLARE @doc_id [CHAR](25);
DECLARE @suppress_eop BIT;
DECLARE @claim_sequence INT;
DECLARE @servicelinesequence INT; -- the serviceline number within the eob/eop   
DECLARE @line_number [INT];

SET @check_run_id = 155589; -- int
SET @modified_user_id = 3339; -- int
SET @voucher_id = 45532696; -- int
SET @claim_id = 105983454; -- int
SET @claim_ud = '11072025E009436'; -- varchar(25)
SET @doc_type = 'eop'; -- char(5)
SET @doc_id = 'kdw_test_20260115'; -- char(25)
SET @suppress_eop = 0; -- bit
SET @claim_sequence = 1; -- int
SET @servicelinesequence = 1; -- int
SET @line_number = 1; -- int

EXEC [dbo].[check_run_servicelineadj835_redcard] @check_run_id = @check_run_id,                  -- int
                                                  @modified_user_id = @modified_user_id,              -- int
                                                  @voucher_id = @voucher_id,                    -- int
                                                  @claim_id = @claim_id,                      -- int
                                                  @claim_ud = @claim_ud,                     -- varchar(25)
                                                  @doc_type = @doc_type,                     -- char(5)
                                                  @doc_id = @doc_id,                       -- char(25)
                                                  @suppress_eop = @suppress_eop,               -- bit
                                                  @claim_sequence = @claim_sequence,                -- int
                                                  @servicelinesequence = @servicelinesequence,           -- int
                                                  @line_number = @line_number OUTPUT; -- int

SELECT *
FROM [dbo].[check_run_batch_redcard] AS [crbr]
WHERE [crbr].[check_run_id] = @check_run_id
and record like '32%' + @claim_ud +'%'
      --AND [crbr].[line_number] = @line_number;

-------------------------------------------------------------------------------------------------------------------------------------------------

   
 modified 02/21/2018 by elva I wasn't pasing the group code   
 Modified 03/21/2018 by elva OA is specifically looking at claim_procedure_benefit.cob_savings_amount but instead it should be anything  
 from the ineligibles in claim_procedure or claim_procedure_benefit which hasn't been allocated anywhere else.   
 order by claim_procedure_id in order to have the same service number number sequence as service records   
 Modified 03/26/2018 added the logic to get the Line Item Control Number from the original 837 the claim was received on   
 Modified 05/19/2020 we want to start sending 835's for the refund/adjustment transactions.  Refunds do no have adjustment  
  reason codes created.  Instead we will use the ones created for the original claim.  The adjusted claim_procedure will have   
  the field adjusted_claim_procedure_id populated with the original claim_procedure_id   
 if the claim_procedure_status has send an EOP  = 1 this will work.  If we don't send an EOP for refunds we will have to use a different way to get the claim   
  procedure info.  We don't actually write an EOP record for the refunds and we don't actually send them.   
Modified 12/28/2021 Vipul if msa had space 2 and shouldn't have
Modified 06/13/2022 Mike updated recipients ticket 12032
Modified 06/17/2022 Mike updated email from table ticket 12292
modified 05/24/2023 elva error message needs to say check_run_servicelineadj835
modified 01/05/2023 elva took out reference to sqlproduction.  Test101 is being used now and it doesn't have a link to sqlproduction
	but edee is on test101 and training.  These are the only other servers we are running check runs on right now
	modified 09/05/2024 story 35449 by Joe - add SBC segments from claim_procedure_external_edit table to open text field one and open text field two
modified 09/27/2024 story 35449 by Joe - add SBC segments from EOB table to open text field one and open text field two
modified 09/30/2024 story 36355 by Joe - remove special characters from open text fields and keep the open text field size <= 50
modified 10/04/2024 story 36355 by Joe - reduce BRN segment size to 8 for open text field1 and 20 for open text field2 to avoid open text field2 error
modified 10/23/2024 story 37058 by Joe - change BRN segment source table to eob table for co-insurance, co-pay, inelig_PR, ineligrarc
modified 10/25/2024 story 37058 by Joe - modify the BRN segment logic to throw error when we have none from BRN segment source tables
modified 11/04/2024 story 36794 by Joe - modify the BRN segment logic to add check run eob to cover all claim procedures
modified 11/14/2024 story 37598 by Joe - modify the BRN segment logic to use era_adjustment_group and era_adjustment_reason_code
modified 12/03/2024 story 37598 by Joe - removed era_adjustment_group and era_adjustment_reason_code condition for getting BRN value from eob and external_edit 
modified 12/12/2024 story 37598 by Joe - added logic to make sure brn segments are not null
changed 23 Dec 2024

Modified: 12/26/2024	KDW 	38253   adding control number to assign within each procedure loop when writing to file 
modified 12/27/2024 story 38253 by Joe - change logic to get char(50) for cClaimRelationString, cOpenField1, and cOpenField2 fields
modified 01/03/2025 story 38641 by Joe - get BRN segments for claim ub92 service
Modified: 02/15/2025	KDW 	0   add payment status to avoid duplicates 
Modified: 02/19/2025	KDW 	0   fix write-off arc to default to 45, limit to one CO per line 
Modified: 02/19/2025	KDW 	0   add cas segments for
	CAS segment:
		CAS01: 1 (Paid amount exceeds billed charges)
		CAS02: 20.00 (Adjustment Amount)
Modified: 02/27/2025	KDW 	40116   update edits to use global sort order 
Modified: 03/24/2025	KDW 	40429   update control number to associate to claim procedure line when possible. 
Modified: 04/24/2025	KDW 	40758   'update payment file to include capitation and $0 service ' 
Modified: 04/30/2025    PS      39579   added call to check_run_serviceline_netting_redcard to process overpayment netting
Modified: 07/25/2025	PM		41963   Payment File ServiceLineAdjustments record 32 version update to version 07
Modified: 07/28/2025	KDW 	42120   Update to use claim_procedure_ineligible 
Modified: 11/24/2025	KDW 	44104   Fix missing default ineligible 
Modified: 12/18/2025	PS		44104   Fixed ineligible description 
Modified: 01/15/2026	KDW 	44821   update PR ineligible to include rarc when available 
Modified: 05/28/2026	KDW 	46499   updated cob to oa23 ER CAB 
Modified: 06/11/2026	PS      46972   using absolute value for [charges] - [allowed_amount] to support claim reversals
Modified: 09/02/2026	PM      47664   Exclude FADJOFFSET from service-line CAS; prior paid amount is represented through PLB
--------------------------------------------------------------------------------------------------------------**/
-- Local Variables 
----------------------------------------  
DECLARE @return_status INT;
DECLARE @record CHAR(627);
DECLARE @tab CHAR;
DECLARE @fd CHAR;
DECLARE @fq CHAR;
DECLARE @zero CHAR(15);

DECLARE @work_amount MONEY; -- elva added 09/02/2011  
DECLARE @work_int INT; -- elva added 09/02/2011  
DECLARE @workfield VARCHAR(6); -- the character counter of docid   

DECLARE @record_count INT;
DECLARE @record_id INT;
DECLARE @patient_name VARCHAR(30);
DECLARE @adjusted_claim BIT; -- elva 05/19/2020  
                             -- Claim Procedure Information  
DECLARE @claim_procedure_id INT;
DECLARE @procedure_code_ud VARCHAR(10);
DECLARE @charges MONEY;
DECLARE @net_amount MONEY;
DECLARE @contract_amount MONEY;
DECLARE @withhold_amount MONEY;

DECLARE @write_off MONEY;
DECLARE @prior_payer_paid_amount MONEY; -- If we're the secondary payer, the dollars paid by the primary payer must be reported as CAS*OA*23   

DECLARE @cob_deducted MONEY;
DECLARE @copay MONEY;
DECLARE @coinsurance MONEY;
DECLARE @deductible MONEY;
DECLARE @ineligible_amount MONEY;
DECLARE @procedure_ineligible_amount MONEY;
DECLARE @benefit_ineligible_amount MONEY;
DECLARE @cob_savings MONEY;
DECLARE @capitation_amount MONEY; --KDW 20250424
DECLARE @first_claim_procedure BIT;
DECLARE @plan_pay VARCHAR(3); -- elva 09/02/2011  
DECLARE @checkbook_withhold MONEY; -- elva 06/11/2012  
DECLARE @msa_paid_amount MONEY; -- elva 12/27/2013  
DECLARE @patient_responsibility MONEY; -- elva 12/27/2013  
DECLARE @place_of_service_ud CHAR(2);
DECLARE @units CHAR(10);
DECLARE @inelig_PR MONEY;
DECLARE @inelig_CO MONEY;
DECLARE @inelig_PI MONEY;
DECLARE @inelig_OA MONEY;

DECLARE @adj_amount_char CHAR(15); -- to convert the adjustment amount to character   

DECLARE @claim_cob_deducted MONEY; -- on eop it is claim_carrier   
DECLARE @claim_ineligible_amount MONEY;
DECLARE @claim_charges MONEY;
DECLARE @claim_net_discount MONEY;
DECLARE @claim_copay MONEY;
DECLARE @claim_deductible MONEY;
DECLARE @claim_net_amount MONEY;
DECLARE @claim_coinsurance MONEY;
DECLARE @claim_withhold MONEY;
DECLARE @claim_msa_paid MONEY; -- elva 12/30/2013  
DECLARE @claim_paid MONEY; -- elva 12/30/2013 was claim_patient_paid   
DECLARE @claim_patient_responsibility MONEY; -- @deductible + @coinsurance_amount + @copay_amount - @msa_total_used  
DECLARE @cas_adj MONEY; --kdw 20250219

DECLARE @claim_write_off MONEY;
-- declare @claim_prior_payer_paid_amount  money   -- If we're the secondary payer, the dollars paid by the primary payer must be reported as CAS*OA*23   

DECLARE @claim_procedure_ineligible_amount MONEY;
DECLARE @claim_benefit_ineligible_amount MONEY;
DECLARE @claim_contract_amount MONEY;

DECLARE @claim_charges_char CHAR(15);
DECLARE @claim_contract_amount_char CHAR(15);
DECLARE @claim_ineligible_amount_char CHAR(15);
DECLARE @claim_deductible_char CHAR(15);
DECLARE @claim_net_amount_char CHAR(15);
DECLARE @claim_copay_char CHAR(15);
DECLARE @claim_coinsurance_char CHAR(15);
DECLARE @claim_cob_deducted_char CHAR(15);
DECLARE @claim_patient_responsibility_char CHAR(15);
-- Procedure Code  
DECLARE @procedure_code_nm VARCHAR(30);
DECLARE @claim_procedure_eob VARCHAR(450);

DECLARE @ded_eob VARCHAR(10) = '606';
DECLARE @copay_eob VARCHAR(10) = '605';
DECLARE @coins_eob VARCHAR(10);
DECLARE @ded_gc VARCHAR(2) = 'PR';
DECLARE @copay_gc VARCHAR(2) = 'PR';
DECLARE @coins_gc VARCHAR(2) = 'PR';
DECLARE @coins_carc VARCHAR(15) = '2';
DECLARE @copay_carc VARCHAR(15) = '3';
DECLARE @ded_carc VARCHAR(15) = '1';

DECLARE @inelig_code VARCHAR(50);
DECLARE @inelig_name VARCHAR(100);
DECLARE @writeoff_code VARCHAR(50);
DECLARE @writeoff_name VARCHAR(100);

-- Error log  
DECLARE @error_message VARCHAR(2000);
SET @error_message = '';
DECLARE @reclen INT;
DECLARE @x12_837_2300_id INT;

DECLARE @check_run_eop_claim_procedure_id INT;
DECLARE @claim_sequence_char CHAR(6);
DECLARE @subscriber_id_char CHAR(20);
DECLARE @servicelinesequence_char CHAR(6);
DECLARE @claim_line_sequence_char CHAR(3);
DECLARE @first_time BIT;
DECLARE @servicelinenumber INT; -- the number of occurrances o f the service line   
DECLARE @servicelinenumber_char CHAR(3);
DECLARE @save_claim_procid INT;

DECLARE @claimrelationship_char CHAR(50); -- Joe 12/27/2024
DECLARE @mi_bill_type CHAR(1); -- Joe 01/03/2025
DECLARE @enable_netting BIT = 1;

DECLARE @recordType VARCHAR(3) = '32';
DECLARE @recordVersion VARCHAR(3) = '07';
DECLARE @serviceLineAdjustmentsTable [dbo].[check_run_32_ServiceLineAdjustments_type];
--------------------------------------------------------------------------------------------------
--LOAD EMAIL INFORMATION FROM TABLE --MODIFIED by MikeZharov 6/17/2022, 
-------------------------------------------------------------------------------------------------
--backup
DECLARE @recipients2 VARCHAR = 'tech.operations@webtpa.com; elva.bass@webtpa.com';
DECLARE @mailitem_id2 INT;

DECLARE @ProgramName VARCHAR(100) = 'CheckRun_Redcard';
DECLARE @NotificationType VARCHAR(50) = 'ERROR';
DECLARE @Notif_from VARCHAR(50) = '';
DECLARE @Notif_to VARCHAR(100) = NULL;
DECLARE @Notif_cc VARCHAR(500) = '';
DECLARE @Email_Format VARCHAR(20) = '';
DECLARE @Email_Importance VARCHAR(20) = '';
DECLARE @Email_Subject VARCHAR(300) = '';
DECLARE @Email_Body VARCHAR(1000) = '';
DECLARE @Email_secure BIT = 0;
DECLARE @mailitem_id INT;
DECLARE @body VARCHAR(MAX);
DECLARE @server_name VARCHAR(100);


--get contacts for error email
EXEC [dbo].[email_notification_contacts] @ProgramName = @ProgramName,                  -- varchar(100)
                                         @NotificationType = @NotificationType,        -- varchar(50)
                                         @Notif_from = @Notif_from OUTPUT,             -- varchar(50)
                                         @Notif_to = @Notif_to OUTPUT,                 -- varchar(100)
                                         @Notif_cc = @Notif_cc OUTPUT,                 -- varchar(500)
                                         @Email_Format = @Email_Format OUTPUT,         -- varchar(20)
                                         @Email_Importance = @Email_Importance OUTPUT, -- varchar(20)
                                         @Email_Subject = @Email_Subject OUTPUT,       -- varchar(300)
                                         @Email_Body = @Email_Body OUTPUT,             -- varchar(1000)
                                         @Email_secure = @Email_secure OUTPUT;         -- bit

--Print Convert(VARCHAR(100), @ProgramName) 
--Print Convert (VARCHAR(50), @NotificationType)
--Print Convert (VARCHAR(50), @Notif_from)
--Print Convert (VARCHAR(100),@Notif_to)
--Print Convert (VARCHAR(500), @Notif_cc)
--Print Convert (VARCHAR(20), @Email_Format)
--Print Convert (VARCHAR(20), @Email_Importance)
--Print Convert (VARCHAR(300), @Email_Subject)
--Print Convert (VARCHAR(1000), @Email_Body)
--Print Convert (Bit, @Email_secure)
--Print Convert (INT, @mailitem_id)
--Print Convert (VARCHAR(MAX), @body)
--Print Convert (VARCHAR(100), @server_name)

-------------------------------------------------------------------------------------------------------------
DECLARE @is_inst_claim BIT; -- elva 03/26/2018  
                            --declare @claim_procedure Table  (  
CREATE TABLE [#claim_procedure]
(
    [claimprocs_id] INT IDENTITY NOT NULL,
    [claim_procedure_id] INT,
    [sequence_number] INT,
    [procedurecode_ud] VARCHAR(15),
    [modifier_1] VARCHAR(5),
    [modifier_2] VARCHAR(5),
    [modifier_3] VARCHAR(5),
    [modifier_4] VARCHAR(5),
    [charges] MONEY,
    [net_amount] MONEY,
    [write_off] MONEY,
    [prior_payer_paid_amount] MONEY,   -- If we're the secondary payer, the dollars paid by the primary payer must be reported as CAS*OA*23  

    [inelig_amount] MONEY,
    [copay_amount] MONEY,
    [deductible_amount] MONEY,
    [coinsurance_amount] MONEY,
    [cob_savings_amount] MONEY,
    [capitation_amount] MONEY,         --KDW 20250424
    [anesthesia_minutes] INT,
    [units] INT,
    [facility_type_code_4010A1] VARCHAR(2),
    [diagnosis_1] INT,
    [diagnosis_2] INT,
    [diagnosis_3] INT,
    [diagnosis_4] INT,
    [emg] BIT,
    [epsdt] BIT,
    [from_service_date] SMALLDATETIME,
    [to_service_date] SMALLDATETIME,
    [adjusted_claim_procedure_id] INT, -- elva 05/19/20  
    [line_denied] BIT,
                                       --[inelig_gc] VARCHAR(2),            -- claim adjust group code for ineligibile ( is patient or provider responsible for ineligible? )  
                                       --[inelig_arc] VARCHAR(15),          -- claim adjust reason code for ineligibile  
                                       --[inelig_rarc] VARCHAR(30),         -- claim remark code for ineligible  
                                       --[inelig_code] VARCHAR(50),         --assigning edit code to brn from table kdw 20250227
                                       --[inelig_name] VARCHAR(100),        --assigning edit description to brn from table kdw 20250227
    [write_off_gc] VARCHAR(2),         -- claim adjust group code for write off (will default to CO45 if null)  
    [write_off_arc] VARCHAR(15),       -- claim adjust reason code for write off (will default to CO45 if null)  
    [write_off_rarc] VARCHAR(30),      -- claim remark code for ineligible for write off (usually not used)  
    [write_off_code] VARCHAR(50),      --assigning edit code to brn from table kdw 20250227
    [write_off_name] VARCHAR(100),     --assigning edit description to brn from table kdw 20250227
    [msa_paid_amount] MONEY,           -- consumer spending account (HRA) will be sent in OA/187   
    [p_2400_REF_6R] VARCHAR(50),       --adding provider control number to the temp table KDW 20241226
    [cas_01_1_2] MONEY                 --KDW 20250219 adding cas adj for paid amt vs charges
);

DECLARE @adjustment_reason_codes TABLE
(
    [sort_key] INT IDENTITY(1, 1), -- the sort order on this table is critical to an accurate ERA  
    [claim_procedure_id] INT,
                                   --[is_clinical_edit] BIT,  --will this still be necessary?
    [is_denial_code] BIT,
    [adjustment_group_code] VARCHAR(2),
    [adjustment_reason_code] VARCHAR(15),
    [remark_code] VARCHAR(30),
    [sort_order] INT,              --KDW 20250227
    [edit_code] VARCHAR(50),       --KDW 20250227
    [description] VARCHAR(100)     --KDW 20250227
);

DROP TABLE IF EXISTS [#ineligible_fields];
CREATE TABLE [#ineligible_fields]
(
    [claim_procedure_ineligible_id] INT,
    [claim_procedure_id] INT,
    [adjustment_group_code] VARCHAR(2),
    [adjustment_reason_code] VARCHAR(15),
    [remark_code] VARCHAR(30),
    [inelig_amount] MONEY,
    [eob_ud] VARCHAR(50),
    [eob_name] VARCHAR(50)
);
--might need to build this later
--CREATE NONCLUSTERED INDEX IX_Name ON [#ineligible_fields] ([claim_procedure_id])
-----------------------------------------------  
-- Initialize Variables  
-----------------------------------------------  
SET @return_status = 0;
SET @fd = ',';
SET @fq = '"';
SET @tab = CHAR(9);

SET @claim_cob_deducted = 0;
SET @claim_ineligible_amount = 0;
SET @claim_charges = 0;
SET @claim_net_discount = 0;
SET @claim_copay = 0;
SET @claim_deductible = 0;
SET @claim_net_amount = 0;
SET @claim_coinsurance = 0;
SET @claim_withhold = 0;
SET @claim_msa_paid = 0;
SET @claim_paid = 0;
SET @claim_patient_responsibility = 0;

SET @claim_write_off = 0;
-- set @claim_prior_payer_paid_amount = 0  

SET @claim_procedure_ineligible_amount = 0;
SET @claim_benefit_ineligible_amount = 0;
SET @claim_contract_amount = 0;

SET @first_time = 1;
SET @first_claim_procedure = 1;
SET @servicelinesequence = 0;
SET @servicelinenumber = 1;


SET @claim_sequence_char = CONVERT(CHAR(6), @claim_sequence);
SELECT @claim_sequence_char = REPLICATE('0', 6 - LEN(@claim_sequence_char)) + @claim_sequence_char;

SET @zero = '0.00';


DECLARE @write_off_gc VARCHAR(2);
DECLARE @write_off_arc VARCHAR(5);
DECLARE @write_off_rarc VARCHAR(30);
DECLARE @write_off_amount MONEY;

DECLARE @inelig_gc VARCHAR(2);
DECLARE @inelig_arc VARCHAR(5);
DECLARE @inelig_rarc VARCHAR(30);
DECLARE @inelig_amount MONEY;

DECLARE @line_denied BIT;

DECLARE @claim_type_id INT;

DECLARE @2400_REF_6R VARCHAR(50); -- Provider line item control number  


DECLARE @eob_ud_ VARCHAR(50) = NULL;
DECLARE @eob_nm_ VARCHAR(50) = NULL;
DECLARE @eob_ud CHAR(50);
DECLARE @eob_nm CHAR(50);

--------------------------------------------------  
-- Used for secondary payer information  
--------------------------------------------------  
SELECT @claim_type_id = [claim_type_id],
       @x12_837_2300_id = [x12_837_2300_id] --kdw 20250114 update value for pulling the ref for inst claims
FROM [claim]
WHERE [claim_id] = @claim_id;

-----------------------------------------------  
-- Get Claim Procedure Rows  
-----------------------------------------------  
-- turn this into a table and step through versus cursor   
BEGIN TRY
    DELETE FROM [#claim_procedure];

    INSERT INTO [#claim_procedure]
    (
        [claim_procedure_id],
        [procedurecode_ud],
        [modifier_1],
        [modifier_2],
        [modifier_3],
        [modifier_4],
        [charges],
        [net_amount],
        [write_off],
        [prior_payer_paid_amount],     -- If we're the secondary payer, the dollars paid by the primary payer must be reported as CAS*OA*23  
        [copay_amount],
        [deductible_amount],
        [coinsurance_amount],
        [cob_savings_amount],
        [capitation_amount],
        [msa_paid_amount],
        [anesthesia_minutes],
        [units],
        [facility_type_code_4010A1],
        [diagnosis_1],
        [diagnosis_2],
        [diagnosis_3],
        [diagnosis_4],
        [emg],
        [epsdt],
        [from_service_date],
        [to_service_date],
        [adjusted_claim_procedure_id], -- elva 05/19/2020  
        [line_denied],
        [write_off_gc],
        [write_off_arc],
        [write_off_rarc],
        [cas_01_1_2]
    )
    SELECT [cp].[claim_procedure_id],
           [cp].[procedurecode_ud],
           [cp].[modifier_1],
           [cp].[modifier_2],
           [cp].[modifier_3],
           [cp].[modifier_4],
           ISNULL([cp].[charges], 0),
           ISNULL([cpb].[net_amount], 0),
                                                                        -- 06/27/2019 JJT If we're the secondary payer, the dollars paid by the primary payer must be reported as CAS*OA*23  
                                                                        -- This is only configured for Med-Sup claims as of this update but should be properly expanded for all secondary payer claims.  
                                                                        --  To properly implement this we'd likely need a new column on the service lines to hold prior payer paid amounts.  
                                                                        --  For Med-Sup claims the prior payer paid amount has been placed in write_off (HUGE ASSUMPTION).  We're moving it to the prior_payer_paid_amount column.  
                                                                        -- , isnull(cp.write_off,0)  
           CASE
               WHEN @claim_type_id IN ( 5, 6 ) THEN
                   0
               ELSE
                   ISNULL([cp].[write_off], 0)
           END [write_off],
           CASE
               WHEN @claim_type_id IN ( 5, 6 ) THEN
                   ISNULL([cp].[write_off], 0)
               ELSE
                   0
           END [prior_payer_paid_amount],
           ISNULL([cpb].[copay_amount], 0),
           ISNULL([cpb].[deductible], 0),
           ISNULL([cpb].[coinsurance_amount], 0),
           ISNULL([cpb].[cob_savings_amount], 0),
           ISNULL([cp].[capitation_amount], 0),
           ISNULL([cpb].[msa_paid], 0),                                 -- 01/15/2014 We'll use OA/187 with negative dollar amount to indicate the HRA increased payment amount      
           [cp].[anesthesia_minutes],
           [cp].[units],
           [pos].[facility_type_code_4010A1],
           [cp].[diagnosis_1],
           [cp].[diagnosis_2],
           [cp].[diagnosis_3],
           [cp].[diagnosis_4],
           [cp].[emg],
           [cp].[epsdt],
           [cp].[from_service_date],
           [cp].[to_service_date],
           [cp].[adjusted_claim_procedure_id],                          -- elva 05/19/2020  
           CASE
               WHEN [cpb].[copay_amount] IS NOT NULL
                    AND [cpb].[copay_amount] <> 0 THEN
                   0
               WHEN [cpb].[coinsurance_amount] IS NOT NULL
                    AND [cpb].[coinsurance_amount] <> 0 THEN
                   0
               WHEN [cpb].[deductible] IS NOT NULL
                    AND [cpb].[deductible] <> 0 THEN
                   0
               WHEN [cpb].[net_amount] IS NOT NULL
                    AND [cpb].[net_amount] <> 0 THEN
                   0
               ELSE
                   1 -- line denied  
           END,
                                                                        --NULL,                                                        -- inelig_gc  claim adjust group code for ineligibile  
                                                                        --NULL,                                                        -- inelig_arc  claim adjust reason code for ineligibile  
                                                                        --NULL,                                                        -- inelig_rarc  claim remark code for ineligibile  
           NULL,                                                        -- write_off_gc  claim adjust group code for write off (will default to CO45 if null)  
           NULL,                                                        -- write_off_arc  claim adjust reason code for write off (will default to CO45 if null)  
           NULL,                                                        -- write_off_rarc  claim remark code for ineligible for write off (usually not used)  
        -- CASE WHEN [cps].[show_on_835] = 1 THEN 0 
		      --ELSE KDW 20250926
			  ABS(ISNULL([cp].[charges], 0)) - ABS(ISNULL([cp].[allowed_amount], 0))     [cas_01_1_2] --KDW 20250219 -- adding ABS 46972
	 
    FROM [claim_procedure] [cp]
        INNER JOIN [claim_procedure_status] [cps]
            ON [cp].[claim_procedure_status_id] = [cps].[claim_procedure_status_id]
         --KDW 20250926      AND ([cps].[show_on_eop] = 1 OR [cps].[show_on_835] = 1) -- some procedure lines on some claims are not part of the check total and are only used for internal purposes (like FADJ Adjustments)  

        -- 3/7/2013 jjt When we split a claim accross multiple vouchers we want to report only the service lines applied to each voucher  
        INNER JOIN [voucher_claim_procedure_map] [m]
            ON [cp].[claim_procedure_id] = [m].[claim_procedure_id]
               AND [m].[deleted] = 0
        INNER JOIN [voucher_payment] [vp]
            ON [m].[voucher_id] = [vp].[voucher_id]
               AND [vp].[deleted] = 0
        INNER JOIN [voucher_payment_rule] [vr]
            ON [vp].[voucher_payment_id] = [vr].[voucher_payment_id]
        LEFT JOIN [place_of_service] [pos]
            ON [cp].[place_of_service_id] = [pos].[place_of_service_id]
        LEFT JOIN
        (
            SELECT [claim_procedure_benefit].[claim_procedure_id] AS [claim_procedure_id],
                   SUM(ISNULL([claim_procedure_benefit].[cob_savings_amount], 0)) AS [cob_savings_amount],
                   SUM(ISNULL([claim_procedure_benefit].[copay_amount], 0)) AS [copay_amount],
                   SUM(ISNULL([claim_procedure_benefit].[coinsurance_amount], 0)) AS [coinsurance_amount],
                   SUM(ISNULL([claim_procedure_benefit].[deductible], 0)) AS [deductible],
                   SUM(ISNULL([claim_procedure_benefit].[ineligible_amount], 0)) AS [benefit_ineligible_amount],
                   --, SUM (isnull(claim_procedure_benefit.hra_amount,0)) as hra_amount  
                   SUM(ISNULL([claim_procedure_benefit].[net_amount], 0)) AS [net_amount],
                   -- 01/15/2014  the check amount will now be raised by msa_paid during vouchering so add it to net_amount here to keep balance with check_amount  
                   SUM(ISNULL([claim_procedure_benefit_msa].[used_total], 0)) AS [msa_paid]
            FROM [claim_procedure]
                INNER JOIN [claim_procedure_benefit]
                    ON [claim_procedure].[claim_procedure_id] = [claim_procedure_benefit].[claim_procedure_id]
                LEFT JOIN [claim_procedure_benefit_msa]
                    ON [claim_procedure_benefit_msa].[claim_procedure_benefit_id] = [claim_procedure_benefit].[claim_procedure_benefit_id]
                       AND [claim_procedure_benefit_msa].[used_total] > 0 -- 3/27/2014 Don't show refunds until we decide it's ok.  Negative amounts are not summed toward the voucher total.  
            WHERE [claim_procedure_benefit].[deleted] = 0
                  AND [claim_procedure].[claim_id] = @claim_id -- jjt 3/7/2013 added this line to give the engine more options for running the query  
            GROUP BY [claim_procedure_benefit].[claim_procedure_id]
        ) [cpb]
            ON [cp].[claim_procedure_id] = [cpb].[claim_procedure_id]
    WHERE [claim_id] = @claim_id
          AND [vp].[voucher_id] = @voucher_id -- 3/7/2013 jjt Claims split accross multiple vouchers must have their service lines listed on the correct voucher payment  
          AND [vp].[voucher_payment_status_id] IN ( 1, 3 ) --kdw 20250215
		  AND [cp].claim_procedure_status_id NOT IN (124, 125)  -- 47219 Exclude OVPMT/NET STFD
          AND NOT EXISTS
          (
              SELECT 1
              FROM [dbo].[claim_procedure_eob] [cpe47664]
              WHERE [cpe47664].[claim_procedure_id] = [cp].[claim_procedure_id]
                    AND [cpe47664].[eob_id] = 1977 -- FADJOFFSET
          ) -- 47664 Prior paid amount belongs in PLB, not service-line CAS/SVC
    ORDER BY [claim_procedure_id];



    -- if the adjusted_claim_procedure is is populated this is an adjusted claim 05/19/2020 elva  
    SET @adjusted_claim = 0;
    IF EXISTS
    (
        SELECT ISNULL([adjusted_claim_procedure_id], 0)
        FROM [#claim_procedure]
        WHERE [adjusted_claim_procedure_id] > 0
    )
        SET @adjusted_claim = 1;

    -- elva added 03/26/2018  
    SELECT @is_inst_claim = CASE
                                WHEN @claim_type_id IN ( 3, 5, 13 ) THEN
                                    1
                                ELSE
                                    0
                            END;


    /*----------------------------------------------------------------------------------  
     
      **  Do not change the order of these queries!  **  
     
      Everything that uses the @adjustment_reason_codes table depends on this exact order!!     
     
      Load the ERA adjustment codes in the order of selection priority.  The load order is critical.  
     
       1. Clinical Edits (are all denial codes)  
       2. EOBs that are typically used for denials  
       3. EOBs that are not typically used for denials  
     
      If a service line has procedure or benefit ineligible dollars the ERA code is chosen in the order below.  
      The order below is also important when determining the code used with write off if the line is  
      denied.  See the notes where the ARC is selected for write off for details.  
       
      (as of 2/16/2011 per energetic disucssions with Ann & Joe we want clinical edits first)  
       1. First "patient responsibility" clinical edit on the service line.  
       2. First "contractual obligation" clinical edit on the service line.  
       3. First "payer initiated reduction" clinical edit on the service line.  
       4. First "other adjustment" clinical edit on the service line.  
                 
       5. First "patient responsibility" EOB on the service line denial code.  
       6. First "contractual obligation" EOB on the service line denial code.  
       7. First "payer initiated reduction" EOB on the service line denial code.  
       8. First "other adjustment" EOB on the service line denial code.  
  
       9. First "patient responsibility" EOB on the service line non denial code.  
       10. First "contractual obligation" EOB on the service line non denial code.  
       11. First "payer initiated reduction" EOB on the service line non denial code.  
       12. First "other adjustment" EOB on the service line denial non code.     
      
      TODO: We may need to add an era_non_denial_eob_sort_order to the EOB table to help  
       decide whether the first PR or CO non denial EOB should be used for deciding who  
       is responsible for procedure ineligibile amounts when both a PR and CO non denial EOB  
       are present on the service line.  I think this will be rare so for now we'll just   
       look to see if there's a PR anywhere on the line to make the determination.  
  
		!!!! KDW 20250227 Logic above has been replaced !!!!
		From Eric Hill per meeting 2/25/2025 3:00
			Sort Order needs to be decided on by Business and communicated to IT - Eric, Braden, Andrew, Sheila W.
			1. Preferred Ranking will be External Edits, Clinical Edits, Proprietary EOB
				Edit specific Sort Order will drive ranking
		This new ranking will be driven off of new view vw_edit_list which includes
		flb_reason_code from bcbs_claims
		eob from mcr_dc_prod
		clinical_edits from mcr_dc_prod
		other reference tables for external edits will be included in the view later on to 
		drive the era assignments.


		-----------------------------------------------------------------------------------------------------
	
      ----------------------------------------------------------------------------------*/
    --KDW 42120 20250728
    --DELETE FROM @adjustment_reason_codes;


    --    INSERT INTO @adjustment_reason_codes
    --    (
    --        [claim_procedure_id],
    --        [adjustment_group_code],
    --        [adjustment_reason_code],
    --        [remark_code],
    --        [sort_order],
    --        [edit_code],
    --        [description]
    --    )
    --    SELECT [cpe].[claim_procedure_id],
    --           [e].[era_adjustment_group],
    --           [e].[era_adjustment_reason_code],
    --           [e].[era_remark_code],
    --           [vel].[sort_order],
    --           [vel].[edit_code],
    --           LEFT([vel].[description], 100)
    --    FROM [dbo].[vw_edit_list] AS [vel]
    --        INNER JOIN [dbo].[eob] AS [e]
    --            ON [e].[eob_ud] = [vel].[edit_code]
    --        INNER JOIN [dbo].[claim_procedure_eob] AS [cpe]
    --            ON [cpe].[eob_id] = [e].[eob_id]
    --        INNER JOIN [dbo].[claim_procedure] AS [cp]
    --            ON [cp].[claim_procedure_id] = [cpe].[claim_procedure_id]
    --    WHERE [e].[era_adjustment_group] > '0'
    --          AND [cp].[claim_id] = @claim_id;

    --    INSERT INTO @adjustment_reason_codes
    --    (
    --        [claim_procedure_id],
    --        [is_denial_code],
    --        [adjustment_group_code],
    --        [adjustment_reason_code],
    --        [remark_code],
    --        [sort_order],
    --        [edit_code],
    --        [description]
    --    )
    --    SELECT [cpee].[claim_procedure_id],
    --           1,
    --           [ee].[era_adjustment_group],
    --           [ee].[era_adjustment_reason_code],
    --           [ee].[era_remark_code],
    --           [vel].[sort_order],
    --           [vel].[edit_code],
    --           LEFT([vel].[description], 100)
    --    FROM [dbo].[vw_edit_list] AS [vel]
    --        INNER JOIN [dbo].[external_edits] AS [ee]
    --            ON [ee].[edit_code] = [vel].[edit_code]
    --        INNER JOIN [dbo].[claim_procedure_external_edit] AS [cpee]
    --            ON [cpee].[edit_code] = [ee].[edit_code]
    --        INNER JOIN [dbo].[claim_procedure] AS [cp]
    --            ON [cp].[claim_procedure_id] = [cpee].[claim_procedure_id]
    --    WHERE [cpee].[override] = 0
    --          AND [ee].[era_adjustment_group] > '0'
    --          AND [cp].[claim_id] = @claim_id;

    --    INSERT INTO @adjustment_reason_codes
    --    (
    --        [claim_procedure_id],
    --        [is_denial_code],
    --        [adjustment_group_code],
    --        [adjustment_reason_code],
    --        [remark_code],
    --        [sort_order],
    --        [edit_code],
    --        [description]
    --    )
    --    SELECT [cpce].[claim_procedure_id],
    --           1,
    --           [ce].[era_adjustment_group],
    --           [ce].[era_adjustment_reason_code],
    --           [ce].[era_remark_code],
    --           [vel].[sort_order],
    --           [vel].[edit_code],
    --           LEFT([vel].[description], 100)
    --    FROM [dbo].[vw_edit_list] AS [vel]
    --        INNER JOIN [dbo].[clinical_edit] AS [ce]
    --            ON [ce].[aa_rule_number] = [vel].[edit_code]
    --        INNER JOIN [dbo].[claim_procedure_clinical_edit] AS [cpce]
    --            ON [cpce].[clinical_edit_id] = [ce].[clinical_edit_id]
    --        INNER JOIN [dbo].[claim_procedure] AS [cp]
    --            ON [cp].[claim_procedure_id] = [cpce].[claim_procedure_id]
    --    WHERE [cpce].[active] = 1
    --          AND [cpce].[override] = 0
    --          AND [cp].[claim_id] = @claim_id;

    --    IF @is_inst_claim = 1
    --    BEGIN
    --        --we'll still keep the claim_procedure level checks and just add in the ub service line level edits.

    --        INSERT INTO @adjustment_reason_codes
    --        (
    --            [claim_procedure_id],
    --            [is_denial_code],
    --            [adjustment_group_code],
    --            [adjustment_reason_code],
    --            [remark_code],
    --            [sort_order],
    --            [edit_code],
    --            [description]
    --        )
    --        SELECT [cus].[claim_procedure_id],
    --               1,
    --               [e].[era_adjustment_group],
    --               [e].[era_adjustment_reason_code],
    --               [e].[era_remark_code],
    --               [vel].[sort_order],
    --               [vel].[edit_code],
    --               LEFT([e].[description], 100)
    --        FROM [dbo].[vw_edit_list] AS [vel]
    --            INNER JOIN [dbo].[eob] AS [e]
    --                ON [e].[eob_ud] = [vel].[edit_code]
    --            INNER JOIN [dbo].[claim_ub92_service_eob] AS [cuse]
    --                ON [cuse].[eob_id] = [e].[eob_id]
    --            INNER JOIN [dbo].[claim_ub92_service] AS [cus]
    --                ON [cus].[claim_ub92_service_id] = [cuse].[claim_ub92_service_id]
    --            INNER JOIN [dbo].[claim_procedure] AS [cp]
    --                ON [cp].[claim_procedure_id] = [cus].[claim_procedure_id]
    --        WHERE [cus].[claim_procedure_id] IS NOT NULL
    --              AND [cp].[claim_id] = @claim_id;

    --        INSERT INTO @adjustment_reason_codes
    --        (
    --            [claim_procedure_id],
    --            [is_denial_code],
    --            [adjustment_group_code],
    --            [adjustment_reason_code],
    --            [remark_code],
    --            [sort_order],
    --            [edit_code],
    --            [description]
    --        )
    --        SELECT [cus].[claim_procedure_id],
    --               1,
    --               [ee].[era_adjustment_group],
    --               [ee].[era_adjustment_reason_code],
    --               [ee].[era_remark_code],
    --               [vel].[sort_order],
    --               [vel].[edit_code],
    --               LEFT([vel].[description], 100)
    --        FROM [dbo].[vw_edit_list] AS [vel]
    --            INNER JOIN [dbo].[external_edits] AS [ee]
    --                ON [ee].[edit_code] = [vel].[edit_code]
    --            INNER JOIN [dbo].[claim_ub92_service_external_edit] AS [cusee]
    --                ON [cusee].[edit_code] = [ee].[edit_code]
    --            INNER JOIN [dbo].[claim_ub92_service] AS [cus]
    --                ON [cus].[claim_ub92_service_id] = [cusee].[claim_ub92_service_id]
    --            INNER JOIN [dbo].[claim_procedure] AS [cp]
    --                ON [cp].[claim_procedure_id] = [cus].[claim_procedure_id]
    --        WHERE [cusee].[override] = 0
    --              AND [cus].[claim_procedure_id] IS NOT NULL
    --              AND [cp].[claim_id] = @claim_id;

    --        INSERT INTO @adjustment_reason_codes
    --        (
    --            [claim_procedure_id],
    --            [is_denial_code],
    --            [adjustment_group_code],
    --            [adjustment_reason_code],
    --            [remark_code],
    --            [sort_order],
    --            [edit_code],
    --            [description]
    --        )
    --        SELECT [cus].[claim_procedure_id],
    --               1,
    --               [ce].[era_adjustment_group],
    --               [ce].[era_adjustment_reason_code],
    --               [ce].[era_remark_code],
    --               [vel].[sort_order],
    --               [vel].[edit_code],
    --               LEFT([vel].[description], 100)
    --        FROM [dbo].[vw_edit_list] AS [vel]
    --            INNER JOIN [dbo].[clinical_edit] AS [ce]
    --                ON [ce].[aa_rule_number] = [vel].[edit_code]
    --            INNER JOIN [dbo].[claim_ub92_service_clinical_edit] AS [cusce] --we don't use this yet, but including for when we do.
    --                ON [cusce].[clinical_edit_id] = [ce].[clinical_edit_id]
    --            INNER JOIN [dbo].[claim_ub92_service] AS [cus]
    --                ON [cus].[claim_ub92_service_id] = [cusce].[claim_ub92_service_id]
    --            INNER JOIN [dbo].[claim_procedure] AS [cp]
    --                ON [cp].[claim_procedure_id] = [cus].[claim_procedure_id]
    --        WHERE [cusce].[active] = 1
    --              AND [cusce].[override] = 0
    --              AND [cus].[claim_procedure_id] IS NOT NULL
    --              AND [cp].[claim_id] = @claim_id;

    --    END;





    ---- just in case someone puts dirty data in the EOB tables  
    --DELETE FROM @adjustment_reason_codes
    --WHERE LTRIM(ISNULL([adjustment_group_code], '')) NOT IN ( 'PR', 'CO', 'PI', 'OA' )
    --      OR LTRIM(ISNULL([adjustment_reason_code], '')) = '';

    --changing logic to use ineligible tables KDW 20250728

    --debug
    --SELECT * FROM @adjustment_reason_codes AS [arc]

    /*-----------------------------------------------------------------  
     
    Determine ineligible and write off GC/ARC/RARC  
     
    We need to make some determinations before we build the @2100_CLP segment  
    and for convenience its nice to do before we build the CAS segment(s).  
     
    Using the @adjustment_reason_codes table above, that is sorted by denial codes first,  
    we need to pick the best GC/ARC/RARC for two situations.  
     
    1. If a procedure is denied we'll need a denial code on service line.  If we have   
    a denial code that we can tie to the ineligible amount, we'll attach the denial GC/ARC/RARC  
    to the ineligible dollars.  If there is no ineligible amount, we'll need to force   
    the denial code onto the write off dollars using CO*ARC where ARC is the best   
    denial code ARC we can find.  
     
    1.b If we're reporting at the claim level CAS we need to do the same concept as above if  
    ANY of the lines are denied.  A denial code must be reported at the claim level CAS  
    if we're suppressing the service line CAS reporting.  We should rarely be suppressing  
    the service line CAS reporting.  
     
    2. Irrespective of the denial reason, we need to know who is responsible for any   
    ineligible amount to calculate the @2100_CLP05 @patient_responsibility_amount.    
     
    -----------------------------------------------------------------*/

    SET @claim_procedure_id = 0;

    SELECT TOP 1
           @claim_procedure_id = [claim_procedure_id],
           @line_denied = [cp].[line_denied],
           @write_off_amount = ISNULL([cp].[write_off], 0),
           @procedure_code_ud = [cp].[procedurecode_ud]
    --@inelig_amount = ISNULL([cp].[inelig_amount],0)  --kdw 20250728
    FROM [#claim_procedure] [cp]
    ORDER BY [cp].[claim_procedure_id];

    WHILE @@ROWCOUNT = 1
    BEGIN

        --SET @inelig_gc = NULL;
        --SET @inelig_arc = NULL;
        --SET @inelig_rarc = NULL;

        SET @write_off_gc = NULL;
        SET @write_off_arc = NULL;
        SET @write_off_rarc = NULL;

        SET @2400_REF_6R = NULL;

        --Tracy and Kass came up with hierarchy of getting the reference number
        --			First match by seq and procedure code and service date
        --If not then just seq number
        --If not then procedure code and service date
        --KDW 20250815
        --KDW 20250417 missing revised ubs, because it was not using the 2300 id from claim
        IF @is_inst_claim = 1
        BEGIN

		          --kdw 20250814  changing revenue code to a string
                IF LEN(@procedure_code_ud) = 4
                   AND LEFT(@procedure_code_ud, 1) = 'R'
                BEGIN
                    SET @procedure_code_ud = REPLACE(@procedure_code_ud, 'R', '0');
                END;

            SELECT TOP 1
                   @2400_REF_6R = [r].[L2400_ref02_reference]
            FROM [dbo].[claim] AS [c]
                INNER JOIN [Edee].[dbo].[x12_837_2300] [c2] -- elva got rid of sqlproduction  01/05/2023
                    ON [c2].[x12_837_2300_id] = [c].[x12_837_2300_id]
                INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]
                    ON [c2].[x12_837_2300_id] = [cp].[x12_837_2300_id]
                INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r]
                    ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
                INNER JOIN [Edee].[dbo].[x12_837_2400_DTP] AS [xd]
                    ON [xd].[x12_837_2400_id] = [cp].[x12_837_2400_id]
                INNER JOIN [dbo].[claim_ub92] AS [cu] --to look at ub references
                    ON [cu].[claim_id] = [c].[claim_id]
                INNER JOIN [dbo].[claim_ub92_service] AS [cus] --to get claim_procedures that are assigned to that ub line
                    ON [cus].[claim_ub92_id] = [cu].[claim_ub92_id]
                       AND [cus].[row_number] = [cp].[L2400_lx01_assigned_num]
                INNER JOIN [dbo].[claim_procedure] AS [cp3] --to get the sequence number match
                    ON [cp3].[claim_procedure_id] = [cus].[claim_procedure_id]
                       --after a discussion with Tracy, Tania and Nancy it was decided that the row number with the revenue
                       --code on the procedure line will show the reason the decision was made on payment
                       AND [cp3].[procedurecode_ud] = [cus].[revenue_code]
                       
            WHERE [c].[claim_id] = @claim_id
                  --AND [c].[x12_837_2300_id] = @x12_837_2300_id -- Original EDI record, not a repriced record.  
                  AND [r].[L2400_ref01_code] = '6R' -- Provider line item control number 
                  AND [cus].[claim_procedure_id] = @claim_procedure_id
				  AND LEFT([xd].[L2400_dtp02_date],8) = [cp3].[from_service_date]
            ORDER BY [cp].[x12_837_2400_id];

            IF @2400_REF_6R IS NULL
            BEGIN
                --If not then just seq number

                SELECT TOP 1
                       @2400_REF_6R = [r].[L2400_ref02_reference]
                FROM [dbo].[claim] AS [c]
                    INNER JOIN [Edee].[dbo].[x12_837_2300] [c2] -- elva got rid of sqlproduction  01/05/2023
                        ON [c2].[x12_837_2300_id] = [c].[x12_837_2300_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]
                        ON [c2].[x12_837_2300_id] = [cp].[x12_837_2300_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r]
                        ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
                    INNER JOIN [dbo].[claim_ub92] AS [cu] --to look at ub references
                        ON [cu].[claim_id] = [c].[claim_id]
                    INNER JOIN [dbo].[claim_ub92_service] AS [cus] --to get claim_procedures that are assigned to that ub line
                        ON [cus].[claim_ub92_id] = [cu].[claim_ub92_id]
                           AND [cus].[row_number] = [cp].[L2400_lx01_assigned_num]
                    INNER JOIN [dbo].[claim_procedure] AS [cp3] --to get the sequence number match
                        ON [cp3].[claim_procedure_id] = [cus].[claim_procedure_id]
                WHERE [c].[claim_id] = @claim_id
                      --AND [c].[x12_837_2300_id] = @x12_837_2300_id -- Original EDI record, not a repriced record.  
                      AND [r].[L2400_ref01_code] = '6R' -- Provider line item control number 
                      AND [cus].[claim_procedure_id] = @claim_procedure_id
                ORDER BY [cp].[x12_837_2400_id];

            END;
            IF @2400_REF_6R IS NULL
            BEGIN
                --If not then procedure code and service date

                SELECT TOP 1
                       @2400_REF_6R = [r].[L2400_ref02_reference]
                FROM [dbo].[claim] AS [c]
                    INNER JOIN [Edee].[dbo].[x12_837_2300] [c2] -- elva got rid of sqlproduction  01/05/2023
                        ON [c2].[x12_837_2300_id] = [c].[x12_837_2300_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]
                        ON [c2].[x12_837_2300_id] = [cp].[x12_837_2300_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r]
                        ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400_DTP] AS [xd]
                        ON [xd].[x12_837_2400_id] = [cp].[x12_837_2400_id]
                    INNER JOIN [dbo].[claim_ub92] AS [cu] --to look at ub references
                        ON [cu].[claim_id] = [c].[claim_id]
                    INNER JOIN [dbo].[claim_ub92_service] AS [cus] --to get claim_procedures that are assigned to that ub line
                        ON [cus].[claim_ub92_id] = [cu].[claim_ub92_id]
                    INNER JOIN [dbo].[claim_procedure] AS [cp3] --to get the sequence number match
                        ON [cp3].[claim_procedure_id] = [cus].[claim_procedure_id]
                           AND [cp3].[procedurecode_ud] = [cus].[revenue_code] --kdw 20250814 taking this out, because it was causing the lookup to fail
                           
                WHERE [c].[claim_id] = @claim_id
                      --AND [c].[x12_837_2300_id] = @x12_837_2300_id -- Original EDI record, not a repriced record.  
                      AND [r].[L2400_ref01_code] = '6R' -- Provider line item control number 
                      AND [cus].[claim_procedure_id] = @claim_procedure_id
					  AND CAST(LEFT([xd].[L2400_dtp02_date],8) AS DATE) = [cp3].[from_service_date]

                ORDER BY [cp].[x12_837_2400_id];


            END;

			IF @2400_REF_6R IS NULL 
			BEGIN
			
				--If not then just seq number
				SELECT TOP 1 
				    @2400_REF_6R = [r].[L2400_ref02_reference]
				FROM [claim]
				    INNER JOIN [Edee].[dbo].[x12_837_2300] [c] ON [c].[x12_837_2300_id] = [claim].[x12_837_2300_id]
				    INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]  ON [c].[x12_837_2300_id] = [cp].[x12_837_2300_id]
				    INNER JOIN [Edee].[dbo].[x12_837_2400_DTP] AS [xd] ON [xd].[x12_837_2400_id] = [cp].[x12_837_2400_id]
				    INNER JOIN [claim_procedure] [cp2]  ON [cp2].[claim_id] = [claim].[claim_id]  AND [cp2].[sequence_number] = [cp].[L2400_lx01_assigned_num] --joining by sequence in case claim_procedure deleted
				    INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r] ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
				WHERE [claim].[claim_id] = @claim_id
				      AND [cp2].[claim_procedure_id] = @claim_procedure_id -- Match "this" claim procedure  
				      AND [r].[L2400_ref01_code] = '6R' -- Provider line item control number  
				ORDER BY [cp].[x12_837_2400_id];

			END

        END;

        ELSE
        BEGIN


            --KDW 20241226 
            --SELECT -- changed 23 Dec 2024
            --    @2400_REF_6R = [r].[L2400_ref02_reference]
            --FROM [claim]
            --    INNER JOIN [Edee].[dbo].[x12_837_2300] [c]
            --        ON [c].[x12_837_2300_id] = [claim].[x12_837_2300_id]
            --    INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]
            --        ON [c].[x12_837_2300_id] = [cp].[x12_837_2300_id]
            --    INNER JOIN [claim_procedure] [cp2]
            --        ON [cp2].[claim_id] = [claim].[claim_id]
            --           AND [cp2].[sequence_number] = [cp].[L2400_lx01_assigned_num] --joining by sequence in case claim_procedure deleted
            --    INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r]
            --        ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
            --WHERE [claim].[claim_id] = @claim_id
            --      AND [cp2].[claim_procedure_id] = @claim_procedure_id -- Match "this" claim procedure  
            --      AND [r].[L2400_ref01_code] = '6R' -- Provider line item control number  
            --ORDER BY [cp].[x12_837_2400_id];

            --First match by seq and procedure code and service date
            SELECT -- changed 23 Dec 2024
                @2400_REF_6R = [r].[L2400_ref02_reference]
            FROM [claim]
                INNER JOIN [Edee].[dbo].[x12_837_2300] [c]
                    ON [c].[x12_837_2300_id] = [claim].[x12_837_2300_id]
                INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]
                    ON [c].[x12_837_2300_id] = [cp].[x12_837_2300_id]
                INNER JOIN [Edee].[dbo].[x12_837_2400_DTP] AS [xd]
                    ON [xd].[x12_837_2400_id] = [cp].[x12_837_2400_id]
                INNER JOIN [claim_procedure] [cp2]
                    ON [cp2].[claim_id] = [claim].[claim_id]
                       AND [cp2].[sequence_number] = [cp].[L2400_lx01_assigned_num] --joining by sequence in case claim_procedure deleted
                INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r]
                    ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
                       AND [cp2].[procedurecode_ud] = [cp].[L2400_sv101_proc_code]
            WHERE [claim].[claim_id] = @claim_id
                  AND [cp2].[claim_procedure_id] = @claim_procedure_id -- Match "this" claim procedure  
                  AND [r].[L2400_ref01_code] = '6R' -- Provider line item control number  
				  AND CAST(LEFT([xd].[L2400_dtp02_date],8) AS DATE) = [cp2].[from_service_date]
            ORDER BY [cp].[x12_837_2400_id];


            --If not then just seq number
            IF @2400_REF_6R IS NULL
            BEGIN

                SELECT -- changed 23 Dec 2024
                    @2400_REF_6R = [r].[L2400_ref02_reference]
                FROM [claim]
                    INNER JOIN [Edee].[dbo].[x12_837_2300] [c]
                        ON [c].[x12_837_2300_id] = [claim].[x12_837_2300_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]
                        ON [c].[x12_837_2300_id] = [cp].[x12_837_2300_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400_DTP] AS [xd]
                        ON [xd].[x12_837_2400_id] = [cp].[x12_837_2400_id]
                    INNER JOIN [claim_procedure] [cp2]
                        ON [cp2].[claim_id] = [claim].[claim_id]
                           AND [cp2].[sequence_number] = [cp].[L2400_lx01_assigned_num] --joining by sequence in case claim_procedure deleted
                    INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r]
                        ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
                WHERE [claim].[claim_id] = @claim_id
                      AND [cp2].[claim_procedure_id] = @claim_procedure_id -- Match "this" claim procedure  
                      AND [r].[L2400_ref01_code] = '6R' -- Provider line item control number  
                ORDER BY [cp].[x12_837_2400_id];

            END;

            --If not then procedure code and service date
            IF @2400_REF_6R IS NULL
            BEGIN
                SELECT -- changed 23 Dec 2024
                    @2400_REF_6R = [r].[L2400_ref02_reference]
                FROM [claim]
                    INNER JOIN [Edee].[dbo].[x12_837_2300] [c]
                        ON [c].[x12_837_2300_id] = [claim].[x12_837_2300_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400] [cp]
                        ON [c].[x12_837_2300_id] = [cp].[x12_837_2300_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400_DTP] AS [xd]
                        ON [xd].[x12_837_2400_id] = [cp].[x12_837_2400_id]
                    INNER JOIN [claim_procedure] [cp2]
                        ON [cp2].[claim_id] = [claim].[claim_id]
                    INNER JOIN [Edee].[dbo].[x12_837_2400_REF] [r]
                        ON [cp].[x12_837_2400_id] = [r].[x12_837_2400_id]
                           AND [cp2].[procedurecode_ud] = [cp].[L2400_sv101_proc_code]
                WHERE [claim].[claim_id] = @claim_id
                      AND [cp2].[claim_procedure_id] = @claim_procedure_id -- Match "this" claim procedure  
                      AND [r].[L2400_ref01_code] = '6R' -- Provider line item control number  
                ORDER BY [cp].[x12_837_2400_id];

            END;
        END;

        IF @2400_REF_6R IS NULL
           OR LEN(@2400_REF_6R) = 0
            SET @2400_REF_6R = @claim_procedure_id;

        --------------------------------------------------  
        -- If the line is denied we need a denial code in either ineligible amount or write off.    
        -- If we have ineligible amount > 0 attach the denial code to the ineligible amount.  
        -- If we don't have any ineligible amount, attach the denial code to the write off amount.  
        -- We don't want to use the write off amount for the denial code unless we have to because  
        -- the write off amount is almost always set to CO*45 PPO discount.  
        --------------------------------------------------  
        --IF @line_denied = 1
        --BEGIN

        --    -- For ineligible dollars, give preference to PR/CO denial codes first  
        --    IF @inelig_amount > 0
        --       OR
        --       (
        --           @inelig_amount < 0
        --           AND @adjusted_claim = 1
        --       ) -- elva 05/19/2020  
        --    BEGIN

        --        --kdw 20250219 if write off = 0 then CO if not then no CO
        --        IF @write_off_amount = 0
        --        BEGIN

        --            -- try a denial PR/CO code on this service line first  
        --            SELECT TOP 1
        --                   @inelig_gc = [c].[adjustment_group_code],
        --                   @inelig_arc = [c].[adjustment_reason_code],
        --                   @inelig_rarc = [c].[remark_code],
        --                   @inelig_code = [c].[edit_code],
        --                   @inelig_name = [dbo].[fn_StripLineFeed]([c].[description])
        --            FROM @adjustment_reason_codes [c]
        --            WHERE [c].[claim_procedure_id] = @claim_procedure_id
        --                  AND [c].[adjustment_group_code] IN ( 'PR', 'CO' )
        --                  AND [c].[is_denial_code] = 1
        --            ORDER BY [c].[sort_order];


        --            -- try any denial code on this service line next  
        --            IF @inelig_gc IS NULL
        --                SELECT TOP 1
        --                       @inelig_gc = [c].[adjustment_group_code],
        --                       @inelig_arc = [c].[adjustment_reason_code],
        --                       @inelig_rarc = [c].[remark_code],
        --                       @inelig_code = [c].[edit_code],
        --                       @inelig_name = [dbo].[fn_StripLineFeed]([c].[description])
        --                FROM @adjustment_reason_codes [c]
        --                WHERE [c].[claim_procedure_id] = @claim_procedure_id
        --                      AND [c].[is_denial_code] = 1
        --                ORDER BY [c].[sort_order];

        --        END;
        --        ELSE
        --        BEGIN

        --            -- try a denial PR code on this service line first  
        --            SELECT TOP 1
        --                   @inelig_gc = [c].[adjustment_group_code],
        --                   @inelig_arc = [c].[adjustment_reason_code],
        --                   @inelig_rarc = [c].[remark_code],
        --                   @inelig_code = [c].[edit_code],
        --                   @inelig_name = [dbo].[fn_StripLineFeed]([c].[description])
        --            FROM @adjustment_reason_codes [c]
        --            WHERE [c].[claim_procedure_id] = @claim_procedure_id
        --                  AND [c].[adjustment_group_code] IN ( 'PR' )
        --                  AND [c].[is_denial_code] = 1
        --            ORDER BY [c].[sort_order];

        --            -- try any denial code on this service line next  
        --            IF @inelig_gc IS NULL
        --                SELECT TOP 1
        --                       @inelig_gc = [c].[adjustment_group_code],
        --                       @inelig_arc = [c].[adjustment_reason_code],
        --                       @inelig_rarc = [c].[remark_code],
        --                       @inelig_code = [c].[edit_code],
        --                       @inelig_name = [dbo].[fn_StripLineFeed]([c].[description])
        --                FROM @adjustment_reason_codes [c]
        --                WHERE [c].[claim_procedure_id] = @claim_procedure_id
        --                      AND [c].[is_denial_code] = 1
        --                      AND [c].[adjustment_group_code] <> 'CO'
        --                ORDER BY [c].[sort_order];

        --        END;
        --    END;


        -- Only when @inelig_amount = 0 here because we likely already caught a denial code if @ineligible > 0.  
        -- For write off dollars, give preference to the CO denial codes first.  
        --  modified 05/19/2020 refunds will be < 0 , so <> 0.00  
        IF @write_off_amount <> 0
        --AND @inelig_amount = 0
        BEGIN

            --KDW 20250219 confirmed by Sharon and Tracy Write-off should always be CO 45
            ---- try a denial CO code on this service line first  
            --SELECT TOP 1
            --       @write_off_gc = 'CO',
            --       @write_off_arc = [c].[adjustment_reason_code],
            --       @write_off_rarc = [c].[remark_code]
            --FROM @adjustment_reason_codes [c]
            --WHERE [c].[claim_procedure_id] = @claim_procedure_id
            --      AND [adjustment_group_code] = 'CO'
            --      AND [c].[is_denial_code] = 1
            --ORDER BY [c].[sort_key];

            ---- try any denial code on this service line next  
            --IF @write_off_gc IS NULL
            --    SELECT TOP 1
            --           @write_off_gc = 'CO', -- we'll still use CO for denied write off, just over ride ARC/RARC  
            --           @write_off_arc = [c].[adjustment_reason_code],
            --           @write_off_rarc = [c].[remark_code]
            --    FROM @adjustment_reason_codes [c]
            --    WHERE [c].[claim_procedure_id] = @claim_procedure_id
            --          AND [c].[is_denial_code] = 1
            --    ORDER BY [c].[sort_key];


            SET @write_off_gc = 'CO';
            SET @write_off_arc = '45';
            SET @write_off_rarc = '';

            SELECT TOP 1
                   @writeoff_code = [c].[edit_code],
                   @writeoff_name = [dbo].[fn_StripLineFeed]([c].[description])
            FROM @adjustment_reason_codes [c]
            WHERE [c].[claim_procedure_id] = @claim_procedure_id
                  AND [adjustment_group_code] = 'CO'
                  AND [c].[is_denial_code] = 1
            ORDER BY [c].[sort_order];


        END;

        --END;

        --------------------------------------------------  
        -- If the line wasn't denied or we didn't get our denial codes  
        -- above, take whatever we can get here in priority sorted order.  
        --------------------------------------------------  
        --IF @inelig_amount <> 0
        --   AND @inelig_gc IS NULL -- elva 05/15/2020 <>  
        --BEGIN

        --    --KDW 20250219 removing CO from the list of adj groups to pull from
        --    -- try a code on this service line first  
        --    IF @inelig_gc IS NULL
        --        SELECT TOP 1
        --               @inelig_gc = [c].[adjustment_group_code],
        --               @inelig_arc = [c].[adjustment_reason_code],
        --               @inelig_rarc = [c].[remark_code],
        --               @inelig_code = [c].[edit_code],
        --               @inelig_name = [dbo].[fn_StripLineFeed]([c].[description])
        --        FROM @adjustment_reason_codes [c]
        --        WHERE [c].[claim_procedure_id] = @claim_procedure_id
        --              AND [c].[adjustment_group_code] <> 'CO'
        --        ORDER BY [c].[sort_order];

        --    -- fall back to defaults ( don't pick a claim level code here as I don't think it would be any more accurate than the default and could be misleading )  
        --    IF @inelig_gc IS NULL
        --    BEGIN
        --        SET @inelig_gc = 'OA';
        --        SET @inelig_arc = '96'; -- Non-covered charges  
        --                                --set @inelig_rarc = 'N514'  -- Consult plan documents for info on this service. retired 01/01/2011  
        --        SET @inelig_rarc = 'N130'; -- Consult plan documents for info on this service.  
        --        SET @inelig_code = '';
        --        SET @inelig_name = '';

        --        INSERT INTO [era_error_log]
        --        (
        --            [claim_procedure_id],
        --            [inelig_amount],
        --            [error_remark]
        --        )
        --        VALUES
        --        (@claim_procedure_id, @inelig_amount, 'ineligible amount but no adjustment code');
        --    END;
        --END;

        --KDW 20250219 removing this logic
        --IF @write_off_amount <> 0
        --   AND @write_off_gc IS NULL -- elva 05/19/2020 <>   
        --BEGIN
        --    -- try a CO code on this this service line first  
        --    SELECT TOP 1
        --           @write_off_gc = 'CO',
        --           @write_off_arc = [c].[adjustment_reason_code],
        --           @write_off_rarc = [c].[remark_code]
        --    FROM @adjustment_reason_codes [c]
        --    WHERE [c].[claim_procedure_id] = @claim_procedure_id
        --          AND [adjustment_group_code] = 'CO'
        --    ORDER BY [c].[sort_key];


        --    -- fall back to defaults  
        --    IF @write_off_gc IS NULL
        --    BEGIN
        --        SET @write_off_gc = 'CO'; -- Always contractual obligation  
        --        SET @write_off_arc = '45'; -- Fall back to PPO discount if we can't get a better code above.  
        --        SET @write_off_rarc = NULL;
        --    END;
        --END;

        -- save results and get next service line  
        UPDATE [#claim_procedure]
        SET --[inelig_gc] = @inelig_gc,  --kdw 20250728  no longer needed
            --[inelig_arc] = @inelig_arc,  --kdw 20250728  no longer needed
            --[inelig_rarc] = @inelig_rarc,  --kdw 20250728  no longer needed
            --[inelig_code] = @inelig_code,      --kdw 20250228  no longer needed
            --[inelig_name] = @inelig_name,      --kdw 20250228  no longer needed
            [write_off_gc] = @write_off_gc,
            [write_off_arc] = @write_off_arc,
            [write_off_rarc] = @write_off_rarc,
            [write_off_code] = @writeoff_code,      --kdw 20250228
            [write_off_name] = @writeoff_name,      --kdw 20250228
            [p_2400_REF_6R] = @2400_REF_6R,         --KDW 20241226
            [procedurecode_ud] = @procedure_code_ud --kdw 20250814
        WHERE [claim_procedure_id] = @claim_procedure_id;

        --debug
        --SELECT * FROM [#claim_procedure] AS [cp]

        SELECT TOP 1
               @claim_procedure_id = [claim_procedure_id],
               @line_denied = [cp].[line_denied],
               @write_off_amount = [cp].[write_off],
               @procedure_code_ud = [cp].[procedurecode_ud]
        --@inelig_amount = [cp].[inelig_amount]
        FROM [#claim_procedure] [cp]
        WHERE [cp].[claim_procedure_id] > @claim_procedure_id
        ORDER BY [cp].[claim_procedure_id];
    END;
END TRY
BEGIN CATCH
    SET @error_message
        = @error_message + 'Error in step ' + ': Error number ' + CAST(ERROR_NUMBER() AS VARCHAR) + ' at line '
          + CAST(ERROR_LINE() AS VARCHAR) + ': ' + ERROR_MESSAGE();
    SET @return_status = -1;
    SET @Email_Subject = 'check_run_servicelineadj835_redcard fatal error ';
    SET @Email_Body = @error_message;
    --set @return_message = 'The following source directory is missing. "' + coalesce(@source_directory_path, '') + '"'  
    -----------------------------------------------
    --SENDING EMAIL --MODIFIED by MikeZharov 6/17/2022, 
    --------------------------------------------------
    --    SET @Notif_to = 'qizhi.zhu@webtpa.com';
    --SET @Notif_cc = 'qizhi.zhu@webtpa.com';

    EXEC [msdb].[dbo].[sp_send_dbmail] @recipients = @Notif_to,            -- varchar(max)
                                       @copy_recipients = @Notif_cc,       -- varchar(max)
                                       @subject = @Email_Subject,          -- nvarchar(255)
                                       @body = @Email_Body,                -- nvarchar(max)
                                       @body_format = @Email_Format,       -- varchar(20)
                                       @importance = @Email_Importance,    -- varchar(6)
                                       @mailitem_id = @mailitem_id OUTPUT, -- int
                                       @from_address = @Notif_from;        -- varchar(max)

    --SET @recipients2 = 'qizhi.zhu@webtpa.com';


    EXEC [msdb].[dbo].[sp_send_dbmail] @recipients = @recipients2,          -- varchar(max)
                                       @copy_recipients = @Notif_cc,        -- varchar(max)
                                       @subject = @Email_Subject,           -- nvarchar(255)
                                       @body = @Email_Body,                 -- nvarchar(max)
                                       @body_format = @Email_Format,        -- varchar(20)
                                       @importance = @Email_Importance,     -- varchar(6)
                                       @mailitem_id = @mailitem_id2 OUTPUT, -- int
                                       @from_address = @Notif_from;         -- varchar(max)

    ----------------------------------
    ---------------------------------- 
    RETURN @return_status;
END CATCH;

/********************************below is the code from serviceline**********************************************************/

-- end of selecting data now start processing it  
-- how many total records do we need to process  

SET @servicelinenumber = 1; --03/21/2018  

BEGIN TRY
    SELECT @record_count = COUNT(*)
    FROM [#claim_procedure];
    SELECT @record_id = MIN([#claim_procedure].[claimprocs_id])
    FROM [#claim_procedure];

    WHILE @record_id <= @record_count
    BEGIN


        SELECT @claim_procedure_id = [claim_procedure_id],
               @procedure_code_ud = SUBSTRING([procedurecode_ud], 1, 10),
               @write_off = ISNULL([write_off], 0),
               @copay = ISNULL([copay_amount], 0),
               @deductible = ISNULL([deductible_amount], 0),
               @coinsurance = ISNULL([coinsurance_amount], 0),
               @cob_savings = ISNULL([cob_savings_amount], 0),
               @msa_paid_amount = ISNULL([msa_paid_amount], 0),
               @prior_payer_paid_amount = ISNULL([prior_payer_paid_amount], 0),   -- 06/27/2019 jjt  

                                                                                  --kdw 20250729 42120
                                                                                  --@inelig_PR = CASE
                                                                                  --                 WHEN [inelig_gc] = 'PR' THEN
                                                                                  --                     [inelig_amount]
                                                                                  --                 ELSE
                                                                                  --                     0
                                                                                  --             END,
                                                                                  --@inelig_CO = CASE
                                                                                  --                 WHEN [inelig_gc] = 'CO' THEN
                                                                                  --                     [inelig_amount]
                                                                                  --                 ELSE
                                                                                  --                     0
                                                                                  --             END,
                                                                                  --@inelig_PI = CASE
                                                                                  --                 WHEN [inelig_gc] = 'PI' THEN
                                                                                  --                     [inelig_amount]
                                                                                  --                 ELSE
                                                                                  --                     0
                                                                                  --             END,
                                                                                  --@inelig_OA = CASE
                                                                                  --                 WHEN [inelig_gc] = 'OA' THEN
                                                                                  --                     [inelig_amount]
                                                                                  --                 ELSE
                                                                                  --                     0
                                                                                  --             END,
               @claim_ineligible_amount = [inelig_amount] + [cob_savings_amount], -- elva 03/21/2018  one total for all the inelible amounts  
                                                                                  -- inelig_amount is claim_procedure.ineligible_amount + claim_procedure_benefit.ineligible_amount  
               @2400_REF_6R = [p_2400_REF_6R],                                    --KDW 20241227
               @cas_adj = [cas_01_1_2],                                           --KDW 20250219
               @capitation_amount = [capitation_amount]                           --KDW 20250424
        FROM [#claim_procedure]
        WHERE [#claim_procedure].[claimprocs_id] = @record_id;


        --SELECT * FROM [#claim_procedure] AS [cp]

        SET @inelig_PR = 0;
        SET @inelig_CO = 0;
        SET @inelig_PI = 0;
        SET @inelig_OA = 0;

        IF @first_claim_procedure = 1
        BEGIN
            SET @save_claim_procid = @claim_procedure_id;
            SET @first_claim_procedure = 0;
        END;
        ELSE
        BEGIN
            IF @save_claim_procid <> @claim_procedure_id
                SET @servicelinenumber = @servicelinenumber + 1;
            ELSE
            BEGIN
                SET @servicelinenumber = 1;
                SET @save_claim_procid = @claim_procedure_id;
            END;
        END;



        TRUNCATE TABLE [#ineligible_fields];
        --kdw get the codes and edits for the inelig values
		--kdw 44104 update to use left joins so that default values are included

        INSERT INTO [#ineligible_fields]
        (
            [claim_procedure_ineligible_id],
            [claim_procedure_id],
            [adjustment_group_code],
            [adjustment_reason_code],
            [remark_code],
            [inelig_amount],
            [eob_ud],
            [eob_name]
        )
        SELECT [cpi].[claim_procedure_ineligible_id],
               [cpi].[claim_procedure_id],
               [cpi].[claim_adjustment_group_code],
               [cpi].[claim_adjustment_reason_code],
               [cpi].[claim_remittance_remark_code],
               [cpi].[ineligible_amount],
               [vel].[edit_code],
               MIN(LEFT([vel].[description], 50))  --PS 20251218
        FROM [dbo].[claim_procedure_ineligible] AS [cpi]
            left JOIN
            (
                SELECT [e].[eob_ud] AS [edit_code],
                       [cpi].[claim_procedure_ineligible_id]
                FROM [dbo].[claim_procedure_ineligible] AS [cpi]
                    INNER JOIN [dbo].[claim_procedure_eob] AS [cpe]
                        ON [cpe].[claim_procedure_eob_id] = [cpi].[claim_procedure_eob_id]
                           AND [cpe].[claim_procedure_id] = @claim_procedure_id
                    INNER JOIN [dbo].[eob] AS [e]
                        ON [e].[eob_id] = [cpe].[eob_id]
                UNION
                SELECT [cpee].[edit_code] AS [edit_code],
                       [cpi].[claim_procedure_ineligible_id]
                FROM [dbo].[claim_procedure_ineligible] AS [cpi]
                    INNER JOIN [dbo].[claim_procedure_external_edit] AS [cpee]
                        ON [cpee].[claim_procedure_external_edit_id] = [cpi].[claim_procedure_external_edit_id]
                           AND [cpee].[claim_procedure_id] = @claim_procedure_id
                UNION
                SELECT [cpce].[main_explaination_code] AS [edit_code],
                       [cpi].[claim_procedure_ineligible_id]
                FROM [dbo].[claim_procedure_ineligible] AS [cpi]
                    INNER JOIN [dbo].[claim_procedure_clinical_edit] AS [cpce]
                        ON [cpce].[claim_procedure_clinical_edit_id] = [cpi].[claim_procedure_clinical_edit_id]
                    INNER JOIN [dbo].[clinical_edit] AS [ce]
                        ON [ce].[clinical_edit_id] = [cpce].[clinical_edit_id]
                           AND [cpce].[claim_procedure_id] = @claim_procedure_id
            ) [e]
                ON [e].[claim_procedure_ineligible_id] = [cpi].[claim_procedure_ineligible_id]
            left JOIN [dbo].[vw_edit_list] AS [vel]
                ON [e].[edit_code] = [vel].[edit_code]
				WHERE [cpi].[claim_procedure_id] = @claim_procedure_id
		GROUP BY 
			  [cpi].[claim_procedure_ineligible_id],
		      [cpi].[claim_procedure_id],
		      [cpi].[claim_adjustment_group_code],
		      [cpi].[claim_adjustment_reason_code],
		      [cpi].[claim_remittance_remark_code],
		      [cpi].[ineligible_amount],
		      [vel].[edit_code];

        --KDW 42120 if inst, the edits might be at service level
        IF @is_inst_claim = 1
           AND EXISTS
        (
            SELECT 1
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[eob_ud] IS NULL
        )
        BEGIN
		--kdw 44104 update to use left joins so that default values are included

            ;WITH [CTE]
             AS (SELECT DISTINCT
                        [cpi].[claim_procedure_ineligible_id],
                        [cpi].[claim_adjustment_group_code],
                        [cpi].[claim_adjustment_reason_code],
                        [cpi].[claim_remittance_remark_code],
                        [cpi].[ineligible_amount],
                        [vel].[edit_code],
                        LEFT([vel].[description], 50) AS [description]
                 FROM [dbo].[claim_procedure_ineligible] AS [cpi]
                     left JOIN
                     (
                         SELECT [e].[eob_ud] AS [edit_code],
                                [cusi].[claim_procedure_ineligible_id]
                         FROM [dbo].[claim_ub92_service_ineligible] AS [cusi]
                             INNER JOIN [dbo].[claim_ub92_service_eob] AS [cuse]
                                 ON [cuse].[claim_ub92_service_eob_id] = [cusi].[claim_ub92_service_eob_id]
                             INNER JOIN [dbo].[eob] AS [e]
                                 ON [e].[eob_id] = [cuse].[eob_id]
                             INNER JOIN [dbo].[claim_procedure_ineligible] AS [cpi2]
                                 ON [cpi2].[claim_procedure_ineligible_id] = [cusi].[claim_procedure_ineligible_id]
                                    AND [cpi2].[claim_adjustment_reason_code] = [cusi].[claim_adjustment_reason_code]
                                    AND [cpi2].[claim_procedure_id] = @claim_procedure_id
                         UNION
                         SELECT [cusee].[edit_code] AS [edit_code],
                                [cusi].[claim_procedure_ineligible_id]
                         FROM [dbo].[claim_ub92_service_ineligible] AS [cusi]
                             INNER JOIN [dbo].[claim_ub92_service_external_edit] AS [cusee]
                                 ON [cusee].[claim_ub92_service_external_edit_id] = [cusi].[claim_ub92_service_external_edit_id]
                             INNER JOIN [dbo].[claim_procedure_ineligible] AS [cpi2]
                                 ON [cpi2].[claim_procedure_ineligible_id] = [cusi].[claim_procedure_ineligible_id]
                                    AND [cpi2].[claim_adjustment_reason_code] = [cusi].[claim_adjustment_reason_code]
                                    AND [cpi2].[claim_procedure_id] = @claim_procedure_id
                         UNION
                         SELECT [cusce].[main_explaination_code] AS [edit_code],
                                [cusi].[claim_procedure_ineligible_id]
                         FROM [dbo].[claim_ub92_service_ineligible] AS [cusi]
                             INNER JOIN [dbo].[claim_ub92_service_clinical_edit] AS [cusce]
                                 ON [cusce].[claim_ub92_service_clinical_edit_id] = [cusi].[claim_ub92_service_clinical_edit_id]
                             INNER JOIN [dbo].[claim_procedure_ineligible] AS [cpi2]
                                 ON [cpi2].[claim_procedure_ineligible_id] = [cusi].[claim_procedure_ineligible_id]
                                    AND [cpi2].[claim_adjustment_reason_code] = [cusi].[claim_adjustment_reason_code]
                                    AND [cpi2].[claim_procedure_id] = @claim_procedure_id
                     ) [e]
                         ON [e].[claim_procedure_ineligible_id] = [cpi].[claim_procedure_ineligible_id]
                     left JOIN [dbo].[vw_edit_list] AS [vel]
                         ON [e].[edit_code] = [vel].[edit_code]
						 WHERE [cpi].[claim_procedure_id] = @claim_procedure_id)
            UPDATE [i]
            SET [i].[eob_ud] = [CTE].[edit_code],
                [i].[eob_name] = [CTE].[description]
            FROM [#ineligible_fields] [i]
                INNER JOIN [CTE]
                    ON [CTE].[claim_procedure_ineligible_id] = [i].[claim_procedure_ineligible_id]
                       AND [i].[adjustment_group_code] = [CTE].[claim_adjustment_group_code]
                       AND [i].[adjustment_reason_code] = [CTE].[claim_adjustment_reason_code]
            WHERE [i].[eob_ud] IS NULL;


        END;

        --kdw 42120 set this to inelig + cob savings
        --@claim_ineligible_amount
        SELECT @claim_ineligible_amount = SUM([if].[inelig_amount]) + @cob_savings
        FROM [#ineligible_fields] AS [if];


        --IF @inelig_rarc IS NULL -- elva 02/21/2018  
        --    SET @inelig_rarc = '';

        IF @deductible <> 0 -- elva 05/19/2020 <>  
        BEGIN

            SET @eob_ud_ = 'PR1';
            SET @eob_nm_ = 'Deductible Applied';

            SET @record
                = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
                  + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            --set @servicelinenumber = @servicelinenumber + 1   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@deductible, 0));
            -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + @ded_gc + @tab; -- modified 02/21/2018 put pr in adjustmentgroupcode  
            --                                                                          -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
            -- SET @record = RTRIM(@record) + LEFT(@ded_carc + SPACE(5), 5) + @tab + SPACE(5) + @tab; -- modified 02/21/2018 pass rarc   
            --                                                                                        -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;

            --removed selects and added to @adjustment_reason_codes
            --replaced with function on insert --KDW 20250228
            --SET @eob_ud_
            --    = REPLACE(
            --                 REPLACE(
            --                            REPLACE(REPLACE(TRIM(SUBSTRING(@eob_ud_, 1, 50)), CHAR(160), ''), CHAR(9), ''),
            --                            CHAR(10),
            --                            ''
            --                        ),
            --                 CHAR(13),
            --                 ''
            --             );
            --SET @eob_ud = CONVERT(CHAR(50), @eob_ud_);

            --SET @eob_nm_
            --    = REPLACE(
            --                 REPLACE(
            --                            REPLACE(REPLACE(TRIM(SUBSTRING(@eob_nm_, 1, 50)), CHAR(160), ''), CHAR(9), ''),
            --                            CHAR(10),
            --                            ''
            --                        ),
            --                 CHAR(13),
            --                 ''
            --             );
            --SET @eob_nm = CONVERT(CHAR(50), @eob_nm_); -- Joe 12/27/2024

            ---- cAlternateProcedureCode,cOpenField1, cOpenField2,cOpenField3 
            --IF @eob_ud_ = 'none'
            --    SET @record
            --        = RTRIM(@record) + SPACE(15) + @tab + SPACE(50) + @tab + SPACE(50) + @tab + SPACE(50) + @tab;
            --ELSE
            --    SET @record = RTRIM(@record) + SPACE(15) + @tab + @eob_ud + @tab + @eob_nm + @tab + SPACE(50) + @tab; -- Joe 10/23/2024

            SET @record
                = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
                  + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;
            -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            SET @record = RTRIM(@record);
            SET @reclen = LEN(@record);



            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --  cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@deductible, 0),                -- 	cAdjustmentAmount		
                   ISNULL(@ded_gc, ''),                   -- 	cAdjustmentGroupCode			
                   ISNULL(@ded_carc, ''),                 -- 	cAdjustmentReasonCode
                   '',                                    --  cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					



            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );


			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelinerecordadj835: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;

        IF @coinsurance <> 0 -- elva 05/19/2020 <>  
        BEGIN



            SET @eob_ud_ = 'PR2';
            SET @eob_nm_ = 'Coinsurance Applied';

            -- SET @record
            --     = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
            --       + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            -- SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            -- SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@coinsurance, 0));
            -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + @coins_gc + @tab; -- modified 02/21/2018 put pr in adjustmentgroupcode  
            --                                                                            -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
            -- SET @record = RTRIM(@record) + LEFT(@coins_carc + SPACE(5), 5) + @tab + SPACE(5) + @tab; -- modified 02/21/2018 pass rarc  
            --                                                                                          -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;

            --SET @eob_ud_ = 'none';
            --SET @eob_nm_ = 'none';
            --SET @mi_bill_type = 'N'; -- Joe 01/03/2025

            --removed selects and added to @adjustment_reason_codes
            --replaced with function on insert --KDW 20250228

            --SET @eob_ud_
            --    = REPLACE(
            --                 REPLACE(
            --                            REPLACE(REPLACE(TRIM(SUBSTRING(@eob_ud_, 1, 50)), CHAR(160), ''), CHAR(9), ''),
            --                            CHAR(10),
            --                            ''
            --                        ),
            --                 CHAR(13),
            --                 ''
            --             );
            --SET @eob_ud = CONVERT(CHAR(50), @eob_ud_);

            --SET @eob_nm_
            --    = REPLACE(
            --                 REPLACE(
            --                            REPLACE(REPLACE(TRIM(SUBSTRING(@eob_nm_, 1, 50)), CHAR(160), ''), CHAR(9), ''),
            --                            CHAR(10),
            --                            ''
            --                        ),
            --                 CHAR(13),
            --                 ''
            --             );
            --SET @eob_nm = CONVERT(CHAR(50), @eob_nm_); -- Joe 12/27/2024

            ---- cAlternateProcedureCode,cOpenField1, cOpenField2,cOpenField3  
            --IF @eob_ud_ = 'none'
            --    SET @record
            --        = RTRIM(@record) + SPACE(15) + @tab + SPACE(50) + @tab + SPACE(50) + @tab + SPACE(50) + @tab;
            --ELSE
            --    SET @record = RTRIM(@record) + SPACE(15) + @tab + @eob_ud + @tab + @eob_nm + @tab + SPACE(50) + @tab; -- Joe 10/23/2024

            SET @record
                = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
                  + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;
            -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            SET @record = RTRIM(@record);
            SET @reclen = LEN(@record);


            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --  cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@coinsurance, 0),               -- 	cAdjustmentAmount		
                   ISNULL(@coins_gc, ''),                 -- 	cAdjustmentGroupCode			
                   ISNULL(@coins_carc, ''),               -- 	cAdjustmentReasonCode
                   '',                                    --  cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_serviceline_redcardadj835.check_run_record_insert_redcard has occured with servicelinerecordadj835: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;
        IF @copay <> 0 -- elva 05/19/2020 <>  
        BEGIN

            SET @eob_ud_ = 'PR3';
            SET @eob_nm_ = 'Co-payment Applied';



            -- SET @record
            --     = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
            --       + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            -- SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            -- SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@copay, 0));
            -- -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + @copay_gc + @tab; -- modified 02/21/2018 put pr in adjustmentgroupcode  
            --                                                                            -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
            -- SET @record
            --     = RTRIM(@record) + LEFT(@copay_carc + SPACE(5), 5) + @tab + SPACE(5) + @tab; -- modified 02/21/2018 pass rarc  
            --                                                                                                          -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;

            --removed selects and added to @adjustment_reason_codes
            --replaced with function on insert --KDW 20250228
            --SET @eob_ud_
            --    = REPLACE(
            --                 REPLACE(
            --                            REPLACE(REPLACE(TRIM(SUBSTRING(@eob_ud_, 1, 50)), CHAR(160), ''), CHAR(9), ''),
            --                            CHAR(10),
            --                            ''
            --                        ),
            --                 CHAR(13),
            --                 ''
            --             );
            --SET @eob_ud = CONVERT(CHAR(50), @eob_ud_);

            --SET @eob_nm_
            --    = REPLACE(
            --                 REPLACE(
            --                            REPLACE(REPLACE(TRIM(SUBSTRING(@eob_nm_, 1, 50)), CHAR(160), ''), CHAR(9), ''),
            --                            CHAR(10),
            --                            ''
            --                        ),
            --                 CHAR(13),
            --                 ''
            --             );
            --SET @eob_nm = CONVERT(CHAR(50), @eob_nm_); -- Joe 12/27/2024

            ---- cAlternateProcedureCode,cOpenField1, cOpenField2,cOpenField3  
            --IF @eob_ud_ = 'none'
            --    SET @record
            --        = RTRIM(@record) + SPACE(15) + @tab + SPACE(50) + @tab + SPACE(50) + @tab + SPACE(50) + @tab;
            --ELSE
            --    SET @record = RTRIM(@record) + SPACE(15) + @tab + @eob_ud + @tab + @eob_nm + @tab + SPACE(50) + @tab; -- Joe 10/23/2024

            SET @record
                = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
                  + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;
            -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            SET @record = RTRIM(@record);
            SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@copay, 0),                     -- 	cAdjustmentAmount		
                   ISNULL(@copay_gc, ''),                 -- 	cAdjustmentGroupCode			
                   ISNULL(@copay_carc, ''),               -- 	cAdjustmentReasonCode
                   '',                                    --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10							   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );
			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835 record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;
        --IF @inelig_PR <> 0 -- elva 05/19/2020 <>  kdw 42120 20250129
        IF EXISTS
        (
            SELECT 1
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[adjustment_group_code] = 'PR'
        )
        BEGIN

            SET @eob_ud_ = NULL;
            SET @eob_nm_ = NULL;

            --kdw 42120
            --SELECT @inelig_arc = [inelig_arc],
            --       @inelig_rarc = [inelig_rarc],
            --       @eob_ud_ = [inelig_gc] + [inelig_arc],
            --       @eob_nm_ = [inelig_name]
            --FROM [#claim_procedure]
            --WHERE [claim_procedure_id] = @claim_procedure_id
            --      AND [inelig_gc] = 'PR'
            --      AND LEN([inelig_arc]) > 0;

            --KDW 42120
            SELECT @inelig_gc = [if].[adjustment_group_code],
                   @inelig_arc = [if].[adjustment_reason_code],
                   @inelig_rarc = [if].[remark_code],
                   @inelig_PR = [if].[inelig_amount],
                   @eob_ud_ = [if].[adjustment_group_code] + [if].[adjustment_reason_code],
                   @eob_nm_ = [if].[eob_name]
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[adjustment_group_code] = 'PR';

            SET @eob_ud_ = ISNULL(@eob_ud_, 'PR96');
            SET @eob_nm_
                = ISNULL(
                            @eob_nm_,
                            'Non-covered charge(s). At least one Remark Code must be provided (may be comprised of either the NCPDP Reject Reason Code, or Remittance Advice Remark Code that is not an ALERT.) Usage: Refer to the 835 Healthcare Policy Identification Segment (loop 2110 Service Payment Information REF), if present.'
                        );


            IF @inelig_arc IS NULL
            BEGIN
                -- (should never hit this becuase we always assign an ARC)  
                SET @inelig_arc = '96'; -- Non-covered charges  
                                        --set @inelig_rarc = 'N514' -- Consult plan documents for info on this service. 10/18/2011 N514 was retired on 01/01/2011  
                SET @inelig_rarc = 'N130'; -- Consult plan documents for info on this service.  
            END;

			--KDW 44821, this had been part of an else to the above if
              IF @inelig_rarc IS NULL
                SET @inelig_rarc = '';



            -- SET @record
            --     = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
            --       + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- cLabel,cServiceQualifier  
            --SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;  --KDW 20250804

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@inelig_PR, 0));
            -- 03/21/2018 deduct @inelig_pr from @claim_ineligible_amount  
            SET @claim_ineligible_amount = @claim_ineligible_amount - ISNULL(@inelig_PR, 0); -- elva 03/21/2018  
                                                                                             -- cAdjustmentAmount,cAdjustmentGroupCode  
                                                                                             -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'PR' + @tab; -- modified 02/21/2018 put  adjustmentgroupcode  
                                                                                             --                                                                       -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
                                                                                             -- SET @record
                                                                                             --     = RTRIM(@record) + @inelig_arc + SPACE(5 - LEN(RTRIM(@inelig_arc))) + @tab + @inelig_rarc
                                                                                             --       + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
                                                                                             --                                                     -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
                                                                                             -- SET @record
                                                                                             --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
                                                                                             --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
                                                                                             -- --cOriginalProcedureCode  
                                                                                             -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;
                                                                                             -- --KDW 20250228
                                                                                             -- SET @record
                                                                                             --     = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
                                                                                             --       + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;
                                                                                             -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
                                                                                             -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
                                                                                             -- SET @record = RTRIM(@record);
                                                                                             -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;


            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@inelig_PR, 0),                 -- 	cAdjustmentAmount		
                   ISNULL(@inelig_gc, ''),                -- 	cAdjustmentGroupCode			
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10							   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;
        -- Contractual Obligation  
        IF @write_off <> 0 -- elva 05/19/2020  
        BEGIN

            --PRINT 'in write off if'
            -- do we have any CO write off?                
            SET @write_off_arc = NULL;
            SET @write_off_rarc = NULL;

            SET @eob_ud_ = NULL;
            SET @eob_nm_ = NULL;

            SELECT @write_off_arc = [write_off_arc],
                   @write_off_rarc = [write_off_rarc],
                   @eob_ud_ = [write_off_gc] + [write_off_arc], --kdw 20250228
                   @eob_nm_ = [write_off_name]                  --kdw 20250228
            FROM [#claim_procedure]
            WHERE [claim_procedure_id] = @claim_procedure_id
                  AND [write_off_gc] = 'CO'
                  AND LEN([write_off_arc]) > 0;

            --PRINT @write_off_arc +  ' ' + @write_off_rarc

            SET @eob_ud_ = ISNULL(@eob_ud_, '');
            SET @eob_nm_ = ISNULL(@eob_nm_, '');

            IF @write_off_arc IS NULL
            BEGIN
                -- (should never hit this becuase we always assign an ARC)  
                SET @write_off_arc = '45'; -- PPO Discount is the default for write off unless we have a "special" EOB that dictates otherwise.  
            END;

            IF @write_off_rarc IS NULL
                SET @write_off_rarc = '';


            -- SET @record
            --     = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
            --       + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@write_off, 0));
            -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'CO' + @tab; --modified 02/21/2018 put  adjustmentgroupcode  
            --                                                                       -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
            -- SET @record = RTRIM(@record) + @write_off_arc + SPACE(5 - LEN(RTRIM(@write_off_arc))) + @tab;
            -- SET @record = RTRIM(@record) + @write_off_rarc + SPACE(5 - LEN(RTRIM(@write_off_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;


            -- --KDW 20250228
            -- SET @record
            --     = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
            --       + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;
            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@write_off, 0),                 -- 	cAdjustmentAmount		
                   'CO',                                  -- 	cAdjustmentGroupCode		???	
                   ISNULL(@write_off_arc, ''),            -- 	cAdjustmentReasonCode
                   ISNULL(@write_off_rarc, ''),           --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10					   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;
        -- Contractual Obligation  
        --kdw 42120 removing
        --IF @inelig_CO <> 0 -- elva 05/19/2020 <>  
        IF EXISTS
        (
            SELECT 1
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[adjustment_group_code] = 'CO'
        )
        BEGIN

            -- do we have any CO ineligible?               
            SET @inelig_arc = NULL;
            SET @inelig_rarc = NULL;

            SET @eob_ud_ = NULL;
            SET @eob_nm_ = NULL;



            --SELECT @inelig_arc = [inelig_arc],
            --       @inelig_rarc = [inelig_rarc],
            --       @eob_ud_ = [inelig_gc] + [inelig_arc],
            --       @eob_nm_ = [inelig_name]
            --FROM [#claim_procedure]
            --WHERE [claim_procedure_id] = @claim_procedure_id
            --      AND [inelig_gc] = 'CO'
            --      AND LEN([inelig_arc]) > '0';

            SELECT @inelig_gc = [if].[adjustment_group_code],
                   @inelig_arc = [if].[adjustment_reason_code],
                   @inelig_rarc = [if].[remark_code],
                   @inelig_CO = [if].[inelig_amount],
                   @eob_ud_ = [if].[adjustment_group_code] + [if].[adjustment_reason_code],
                   @eob_nm_ = [if].[eob_name]
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[adjustment_group_code] = 'CO';


            SET @eob_ud_ = ISNULL(@eob_ud_, 'CO45');
            SET @eob_nm_ = ISNULL(@eob_nm_, 'PPO Discount');



            IF @inelig_arc IS NULL -- (should never hit this becuase we always assign an ARC)  
                SET @inelig_arc = '45'; -- PPO discount  

            IF @inelig_rarc IS NULL
                SET @inelig_rarc = '';

            SET @record
                = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
                  + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@inelig_CO, 0));
            -- 03/21/2018 deduct @inelig_CO from @claim_ineligible_amount  
            SET @claim_ineligible_amount = @claim_ineligible_amount - ISNULL(@inelig_CO, 0); -- elva 03/21/2018  
                                                                                             -- cAdjustmentAmount,cAdjustmentGroupCode  
                                                                                             -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'CO' + @tab; --modified 02/21/2018 put  adjustmentgroupcode  
                                                                                             --                                                                       -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
                                                                                             -- SET @record = RTRIM(@record) + @inelig_arc + SPACE(5 - LEN(RTRIM(@inelig_arc))) + @tab;
                                                                                             -- SET @record = RTRIM(@record) + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
                                                                                             -- SET @record
                                                                                             --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
                                                                                             --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
                                                                                             -- --cOriginalProcedureCode  
                                                                                             -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;

            -- --KDW 20250228
            -- SET @record
            --     = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
            --       + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;
            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@inelig_CO, 0),                 -- 	cAdjustmentAmount		
                   ISNULL(@inelig_gc, ''),                -- 	cAdjustmentGroupCode ???		???	
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835 record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;
        -- Payor Initiated  

        --kdw 42120 removing
        --IF @inelig_PI <> 0 -- elva 05/19/2020 <>  
        IF EXISTS
        (
            SELECT 1
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[adjustment_group_code] = 'PI'
        )
        BEGIN

            -- do we have any CO ineligible?               
            SET @inelig_arc = NULL;
            SET @inelig_rarc = NULL;
            SET @eob_ud_ = NULL;
            SET @eob_nm_ = NULL;

            --SELECT @inelig_arc = [inelig_arc],
            --       @inelig_rarc = [inelig_rarc],
            --       @eob_ud_ = [inelig_gc] + [inelig_arc],
            --       @eob_nm_ = [inelig_name]
            --FROM [#claim_procedure]
            --WHERE [claim_procedure_id] = @claim_procedure_id
            --      AND [inelig_gc] = 'PI'
            --      AND LEN([inelig_arc]) > 0;

            SELECT @inelig_gc = [if].[adjustment_group_code],
                   @inelig_arc = [if].[adjustment_reason_code],
                   @inelig_rarc = [if].[remark_code],
                   @inelig_PI = [if].[inelig_amount],
                   @eob_ud_ = [if].[adjustment_group_code] + [if].[adjustment_reason_code],
                   @eob_nm_ = [if].[eob_name]
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[adjustment_group_code] = 'PI';

            SET @eob_ud_ = ISNULL(@eob_ud_, 'PI96');
            SET @eob_nm_ = ISNULL(@eob_nm_, 'Non-covered charges');

            IF @inelig_arc IS NULL -- (should never hit this becuase we always assign an ARC)  
            BEGIN
                -- (should never hit this becuase we always assign an ARC)  
                SET @inelig_arc = '96'; -- Non-covered charges  
                                        --set @inelig_rarc = 'N514' -- Consult plan documents for info on this service. retired 01/01/2011  
                SET @inelig_rarc = 'N130'; -- Consult plan documents for info on this service.  
            END;

            IF @inelig_rarc IS NULL
                SET @inelig_rarc = '';

            SET @record
                = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
                  + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(@claim_ud))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@inelig_PI, 0));
            -- 03/21/2018 deduct @inelig_PI from @claim_ineligible_amount  
            SET @claim_ineligible_amount = @claim_ineligible_amount - ISNULL(@inelig_PI, 0); -- elva 03/21/201  
                                                                                             -- cAdjustmentAmount,cAdjustmentGroupCode  
                                                                                             -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'PI' + @tab; -- modified 02/21/2018 put  adjustmentgroupcode  
                                                                                             -- SET @record = RTRIM(@record) + @inelig_arc + SPACE(5 - LEN(RTRIM(@inelig_arc))) + @tab;
                                                                                             -- SET @record = RTRIM(@record) + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
                                                                                             --                                                                                           -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
                                                                                             -- SET @record
                                                                                             --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
                                                                                             --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
                                                                                             -- --cOriginalProcedureCode  
                                                                                             -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;

            -- --KDW 20250228
            -- SET @record
            --     = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
            --       + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;
            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@inelig_PI, 0),                 -- 	cAdjustmentAmount		
                   ISNULL(@inelig_gc, ''),                -- 	cAdjustmentGroupCode ???		???	
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;
        -- Other Adjustments  
        IF @cob_savings <> 0 -- elva 05/19/2020 <>  
        BEGIN

            -- do we have any CO ineligible?               
            SET @inelig_arc = NULL;
            SET @inelig_rarc = NULL;
            SET @eob_ud_ = NULL;
            SET @eob_nm_ = NULL;


            --SELECT @inelig_arc = [inelig_arc],
            --       @inelig_rarc = [inelig_rarc],
            --       @eob_ud_ = [inelig_gc] + [inelig_arc],
            --       @eob_nm_ = [inelig_name]
            --FROM [#claim_procedure]
            --WHERE [claim_procedure_id] = @claim_procedure_id
            --      AND [inelig_gc] = 'OA'
            --      AND LEN([inelig_arc]) > 0;

            SET @inelig_arc = '23';  --46499 changing from 22 to 23
            --SET @inelig_rarc = 'N130';
			SET @inelig_rarc = ''  --46499  change rarc to empty

            SET @eob_ud_ = ISNULL(@eob_ud_, 'OA23');
            SET @eob_nm_ = ISNULL(@eob_nm_, 'This care may be covered by another payer per coordination of benefits.');

            IF @inelig_arc IS NULL -- (should never hit this becuase we always assign an ARC)  
            BEGIN
                -- (should never hit this becuase we always assign an ARC)  
                SET @inelig_arc = '96'; -- Non-covered charges  
                                        --set @inelig_rarc = 'N514' -- Consult plan documents for info on this service. retired 01/01/2011  
                SET @inelig_rarc = 'N130'; -- Consult plan documents for info on this service.  
            END;
            IF @inelig_rarc IS NULL
                SET @inelig_rarc = '';

            SET @record
                = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
                  + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@cob_savings, 0));
            -- 03/21/2018 deduct @cob_savings from @claim_ineligible_amount  
            SET @claim_ineligible_amount = @claim_ineligible_amount - ISNULL(@cob_savings, 0); -- elva 03/21/201  
                                                                                               -- cAdjustmentAmount,cAdjustmentGroupCode  
                                                                                               -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'OA' + @tab; -- modified 02/21/2018 put  adjustmentgroupcode  

            -- -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
            -- SET @record = RTRIM(@record) + '22   ' + @tab + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
            --                                                                                                            -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;
            -- --KDW 20250228
            -- SET @record
            --     = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
            --       + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;

            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits   
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@cob_savings, 0),               -- 	cAdjustmentAmount		
                   'OA',                                  -- 	cAdjustmentGroupCode ???		???	
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835 record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;
        -- Other Adjustments elva 05/19/2020 <>  
        IF EXISTS
        (
            SELECT 1
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[adjustment_group_code] = 'OA'
        )
           OR @claim_ineligible_amount <> 0 -- if there is anything left in claim_ineligible_amount elva 03/21/2018  
        BEGIN

            -- do we have any CO ineligible?               
            SET @inelig_arc = NULL;
            SET @inelig_rarc = NULL;
            SET @eob_ud_ = NULL;
            SET @eob_nm_ = NULL;

            --SELECT @inelig_arc = [inelig_arc],
            --       @inelig_rarc = [inelig_rarc],
            --       @eob_ud_ = [inelig_gc] + [inelig_arc],KY
            --       @eob_nm_ = [inelig_name]
            --FROM [#claim_procedure]
            --WHERE [claim_procedure_id] = @claim_procedure_id
            --      AND [inelig_gc] = 'OA'
            --      AND LEN([inelig_arc]) > 0;

            SET @inelig_gc = 'OA';

            SELECT @inelig_gc = [if].[adjustment_group_code],
                   @inelig_arc = [if].[adjustment_reason_code],
                   @inelig_rarc = [if].[remark_code],
                   @inelig_OA = [if].[inelig_amount],
                   @eob_ud_ = [if].[adjustment_group_code] + [if].[adjustment_reason_code],
                   @eob_nm_ = [if].[eob_name]
            FROM [#ineligible_fields] AS [if]
            WHERE [if].[adjustment_group_code] = 'OA';

            SET @eob_ud_ = ISNULL(@eob_ud_, 'OA96');
            SET @eob_nm_ = ISNULL(@eob_nm_, 'Non-covered charges');

            IF @inelig_arc IS NULL -- (should never hit this becuase we always assign an ARC)  
            BEGIN
                -- (should never hit this becuase we always assign an ARC)  
                SET @inelig_arc = '96'; -- Non-covered charges  
                                        --set @inelig_rarc = 'N514' -- Consult plan documents for info on this service. retired 01/01/2011  
                SET @inelig_rarc = 'N130'; -- Consult plan documents for info on this service.  
            END;
            IF @inelig_rarc IS NULL
                SET @inelig_rarc = '';

            SET @record
                = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
                  + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@claim_ineligible_amount, 0)); -- was convert(varchar(15),ISNULL(@cob_savings,0)), now do anything left inelible  
                                                                                              -- cAdjustmentAmount,cAdjustmentGroupCode  
                                                                                              -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'OA' + @tab; -- modified 02/21/2018 put  adjustmentgroupcode  
                                                                                              --                                                                       -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
                                                                                              -- SET @record = RTRIM(@record) + @inelig_arc + SPACE(5 - LEN(RTRIM(@inelig_arc))) + @tab;
                                                                                              -- SET @record = RTRIM(@record) + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
                                                                                              --                                                                                           -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
                                                                                              -- SET @record
                                                                                              --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
                                                                                              --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
                                                                                              -- --cOriginalProcedureCode  
                                                                                              -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;
                                                                                              -- --KDW 20250228
                                                                                              -- SET @record
                                                                                              --     = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
                                                                                              --       + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;
                                                                                              -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
                                                                                              -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
                                                                                              -- SET @record = RTRIM(@record);
                                                                                              -- SET @reclen = LEN(@record);

            --IF EXISTS (select 1 from sys.tables where name = 'kdw_5')
            --INSERT INTO kdw_5 VALUES(@record, 'it was here')
            --ELSE

            --SELECT @record AS record, 'it was here' as comment INTO kdw_5


            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@claim_ineligible_amount, 0),   -- 	cAdjustmentAmount		
                   ISNULL(@inelig_gc, ''),                -- 	cAdjustmentGroupCode ???		???	
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );


			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;

        --------------------------------------------------------------  
        -- 06/27/2019 JJT If we're the secondary payer, the dollars paid by the primary payer must be reported as CAS*OA*23  
        -- This is only configured for Med-Sup claims as of this update but should be properly expanded for all secondary payer claims.  
        --  To properly implement this we'd likely need a new column on the service lines to hold prior payer paid amounts.  
        --  For Med-Sup claims the prior payer paid amount has been placed in write_off (HUGE ASSUMPTION).  We're moving it to the prior_payer_paid_amount column.  
        --------------------------------------------------------------  
        IF @prior_payer_paid_amount <> 0 -- elva 05/19/2020 <>  
        BEGIN
            SET @eob_ud_ = NULL;
            SET @eob_nm_ = NULL;

            SET @eob_ud_ = 'OA23';
            SET @eob_nm_
                = 'The impact of prior payer(s) adjudication including payments and/or adjustments. (Use only with Group Code OA)';
            SET @inelig_rarc = '';

            SET @record
                = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
                  + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@prior_payer_paid_amount, 0));
            -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'OA' + @tab;
            -- -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
            -- SET @record = RTRIM(@record) + '23   ' + @tab + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
            --                                                                                                            -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;


            -- --KDW 20250228
            -- SET @record
            --     = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
            --       + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;


            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@prior_payer_paid_amount, 0),   -- 	cAdjustmentAmount		
                   'OA',                                  -- 	cAdjustmentGroupCode ???		???	
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835 record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;


        -- Consumer Spending Account MSA/HRA/HSA/FLEX  
        IF @msa_paid_amount <> 0 -- elva 05/19/2020 <>  
        BEGIN

            SET @eob_ud_ = 'OA187';
            SET @eob_nm_
                = 'Consumer Spending Account payments (includes but is not limited to Flexible Spending Account, Health Savings Account, Health Reimbursement Account, etc.)';

            SET @msa_paid_amount = @msa_paid_amount * -1; -- A negative amount increased the payment  

            -- SET @record
            --     = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
            --       + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@msa_paid_amount, 0));
            -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'OA' + @tab; -- modified 02/21/2018 put  adjustmentgroupcode   12/28/2021 removed extra Space(2) Vipul\Elva
            --                                                                       -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
            -- SET @record = RTRIM(@record) + '187  ' + @tab + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
            --                                                                                                            -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;

            -- --KDW 20250228
            -- SET @record
            --     = RTRIM(@record) + SPACE(15) + @tab + LEFT(@eob_ud_ + SPACE(50), 50) + @tab
            --       + LEFT(@eob_nm_ + SPACE(50), 50) + @tab + SPACE(50) + @tab;

            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits   
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@msa_paid_amount, 0),           -- 	cAdjustmentAmount		
                   'OA',                                  -- 	cAdjustmentGroupCode ???		???	
                   '',                                    -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835 record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;

        IF @cas_adj < 0
        BEGIN



            --set values as static
            SET @inelig_gc = 'CO';
            SET @inelig_arc = '94';
            SET @inelig_rarc = '';



            SET @record
                = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
                  + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(@claim_ud))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@cas_adj, 0));
            -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + @inelig_gc + @tab; -- modified 02/21/2018 put  adjustmentgroupcode  
            -- SET @record = RTRIM(@record) + @inelig_arc + SPACE(5 - LEN(RTRIM(@inelig_arc))) + @tab;
            -- SET @record = RTRIM(@record) + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
            --                                                                                           -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;



            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(50) + @tab + SPACE(50) + @tab + SPACE(50) + @tab;


            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@cas_adj, 0),                   -- 	cAdjustmentAmount		
                   ISNULL(@inelig_gc, ''),                -- 	cAdjustmentGroupCode ???		???	
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;
        END;
        -- Other Adjustments  
       --KDW 20250821 we ended up with two of these.  removing this one
	  -- IF @cob_savings <> 0 -- elva 05/19/2020 <>  
   --     BEGIN

   --         -- do we have any CO ineligible?               
   --         SET @inelig_arc = NULL;
   --         SET @inelig_rarc = NULL;

   --         SELECT @inelig_arc = [inelig_arc],
   --                @inelig_rarc = [inelig_rarc]
   --         FROM [#claim_procedure]
   --         WHERE [claim_procedure_id] = @claim_procedure_id
   --               AND [inelig_gc] = 'OA'
   --               AND LEN([inelig_arc]) > 0;

   --         IF @inelig_arc IS NULL -- (should never hit this becuase we always assign an ARC)  
   --         BEGIN
   --             -- (should never hit this becuase we always assign an ARC)  
   --             SET @inelig_arc = '96'; -- Non-covered charges  
   --                                     --set @inelig_rarc = 'N514' -- Consult plan documents for info on this service. retired 01/01/2011  
   --             SET @inelig_rarc = 'N130'; -- Consult plan documents for info on this service.  
   --         END;
   --         IF @inelig_rarc IS NULL
   --             SET @inelig_rarc = '';

   --         -- SET @record
   --         --     = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
   --         --       + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

   --         SET @servicelinesequence = @servicelinesequence + 1;

   --         -- the count of the service lines on the claim procedrue  
   --         SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
   --         SELECT @servicelinesequence_char
   --             = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

   --         -- the line number of the claim procedure benefit detail   
   --         SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
   --         SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
   --         -- for claim relationship it is claim_ud   
   --         --SET @record
   --         --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
   --         --      + SPACE(50 - (LEN(RTRIM(@claim_ud)))) + @tab;
   --         SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
   --         -- SET @record
   --         --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
   --         --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

   --         -- -- cLabel,cServiceQualifier  
   --         -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

   --         -- now determine service adjustment amount, Service Line Adjustment Group Code,  
   --         SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@cob_savings, 0));
   --         -- 03/21/2018 deduct @cob_savings from @claim_ineligible_amount  
   --         SET @claim_ineligible_amount = @claim_ineligible_amount - ISNULL(@cob_savings, 0); -- elva 03/21/201  
   --                                                                                            -- cAdjustmentAmount,cAdjustmentGroupCode  
   --                                                                                            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + 'OA' + @tab; -- modified 02/21/2018 put  adjustmentgroupcode  

   --         -- -- cAdjustmentReasonCode (CARC) , cSvcRARC (RARC)  
   --         -- SET @record = RTRIM(@record) + '22   ' + @tab + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
   --         --                                                                                                            -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
   --         -- SET @record
   --         --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
   --         --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
   --         -- --cOriginalProcedureCode  
   --         -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;

   --         SET @eob_ud_ = 'none';
   --         SET @eob_nm_ = 'none';
   --         SET @mi_bill_type = 'N'; -- Joe 01/03/2025

   --         SELECT DISTINCT
   --                @mi_bill_type = [ct].[mi_bill_type]
   --         FROM [dbo].[claim] [c]
   --             JOIN [dbo].[claim_procedure] [cp]
   --                 ON [c].[claim_id] = [cp].[claim_id]
   --             JOIN [claim_type] [ct]
   --                 ON [ct].[claim_type_id] = [c].[claim_type_id]
   --         WHERE [cp].[claim_procedure_id] = @claim_procedure_id;

   --         IF @mi_bill_type <> 'U'
   --         BEGIN

   --             SELECT TOP 1
   --                    @eob_ud_ = [eob].[era_adjustment_group] + [eob].[era_adjustment_reason_code], -- eob.eob_ud
   --                    @eob_nm_ = [eob].[description]
   --             FROM [mcr_dc_prod].[dbo].[eob]
   --                 INNER JOIN [mcr_dc_prod].[dbo].[claim_procedure_eob] [cpeob]
   --                     ON [cpeob].[eob_id] = [eob].[eob_id]
   --             WHERE [cpeob].[claim_procedure_id] = @claim_procedure_id
   --                   AND LEN([eob].[era_adjustment_group]) > 0
   --                   AND LEN([eob].[era_adjustment_reason_code]) > 0 -- Joe 12/03/2024
   --                   AND LEN([eob].[description]) > 0
   --             ORDER BY [eob].[eob_id] DESC;

   --             IF @eob_ud_ = 'none'
   --             BEGIN

   --                 SELECT TOP 1
   --                        @eob_ud_ = [era_adjustment_group] + [era_adjustment_reason_code], -- edit_code
   --                        @eob_nm_ = [edit_description]
   --                 FROM [mcr_dc_prod].[dbo].[claim_procedure_external_edit]
   --                 WHERE [claim_procedure_id] = @claim_procedure_id
   --                       AND LEN([era_adjustment_group]) > 0
   --                       AND LEN([era_adjustment_reason_code]) > 0 -- Joe 12/03/2024
   --                       AND LEN([edit_description]) > 0
   --                 ORDER BY [claim_procedure_external_edit_id] DESC;

   --                 IF @eob_ud_ = 'none'
   --                 BEGIN

   --                     SELECT TOP 1
   --                            @eob_ud_ = [eob].[eob_ud],
   --                            @eob_nm_ = [eob].[description]
   --                     FROM [mcr_dc_prod].[dbo].[eob]
   --                         INNER JOIN [mcr_dc_prod].[dbo].[claim_procedure_eob] [cpeob]
   --                             ON [cpeob].[eob_id] = [eob].[eob_id]
   --                     WHERE [cpeob].[claim_procedure_id] = @claim_procedure_id
   --                           AND LEN([eob].[eob_ud]) > 0
   --                           AND LEN([eob].[description]) > 0
   --                     ORDER BY [eob].[eob_id] DESC;

   --                     IF @eob_ud_ = 'none'
   --                     BEGIN

   --                         SELECT TOP 1
   --                                @eob_ud_ = [edit_code],
   --                                @eob_nm_ = [edit_description]
   --                         FROM [mcr_dc_prod].[dbo].[claim_procedure_external_edit]
   --                         WHERE [claim_procedure_id] = @claim_procedure_id
   --                               AND LEN([edit_code]) > 0
   --                               AND LEN([edit_description]) > 0
   --                         ORDER BY [claim_procedure_external_edit_id] DESC;

   --                         IF @eob_ud_ = 'none'
   --                         BEGIN

   --                             SET @eob_ud_ = 'OA22';
   --                             SET @eob_nm_
   --                                 = 'This care may be covered by another payer per coordination of benefits.';

   --                         END;

   --                     END;

   --                 END;

   --             END;

   --         END;

   --         ELSE
   --         BEGIN -- claim ub92 service

   --             SELECT TOP 1
   --                    @eob_ud_ = [e].[eob_ud],
   --                    @eob_nm_ = [cuse].[additional_information]
   --             FROM [dbo].[claim_ub92_service_eob] [cuse]
   --                 JOIN [dbo].[eob] [e]
   --                     ON [e].[eob_id] = [cuse].[eob_id]
   --                 JOIN [dbo].[claim_procedure_eob] [cpe]
   --                     ON [cpe].[eob_id] = [cuse].[eob_id]
   --             WHERE [cpe].[claim_procedure_id] = @claim_procedure_id
   --                   AND LEN([e].[eob_ud]) > 0
   --                   AND LEN([cuse].[additional_information]) > 0
   --             ORDER BY [cuse].[claim_ub92_service_id] DESC;

   --             IF @eob_ud_ = 'none'
   --             BEGIN

   --                 SELECT TOP 1
   --                        @eob_ud_ = [cusee].[edit_code],
   --                        @eob_nm_ = [cusee].[edit_description]
   --                 FROM [dbo].[claim_ub92_service_external_edit] [cusee]
   --                     JOIN [claim_ub92_service_eob] [cuse]
   --                         ON [cuse].[claim_ub92_service_id] = [cusee].[claim_ub92_service_id]
   --                     JOIN [dbo].[claim_procedure_eob] [cpe]
   --                         ON [cpe].[eob_id] = [cuse].[eob_id]
   --                 WHERE [cpe].[claim_procedure_id] = @claim_procedure_id
   --                       AND LEN([cusee].[edit_code]) > 0
   --                       AND LEN([cusee].[edit_description]) > 0
   --                 ORDER BY [cuse].[claim_ub92_service_id] DESC;

   --             END;

   --         END;

   --         SET @eob_ud_
   --             = REPLACE(
   --                          REPLACE(
   --                                     REPLACE(REPLACE(TRIM(SUBSTRING(@eob_ud_, 1, 50)), CHAR(160), ''), CHAR(9), ''),
   --                                     CHAR(10),
   --                                     ''
   --                                 ),
   --                          CHAR(13),
   --                          ''
   --                      );
   --         SET @eob_ud = CONVERT(CHAR(50), @eob_ud_);

   --         SET @eob_nm_
   --             = REPLACE(
   --                          REPLACE(
   --                                     REPLACE(REPLACE(TRIM(SUBSTRING(@eob_nm_, 1, 50)), CHAR(160), ''), CHAR(9), ''),
   --                                     CHAR(10),
   --                                     ''
   --                                 ),
   --                          CHAR(13),
   --                          ''
   --                      );
   --         SET @eob_nm = CONVERT(CHAR(50), @eob_nm_); -- Joe 12/27/2024

   --         -- cAlternateProcedureCode,cOpenField1, cOpenField2,cOpenField3  
   --         IF @eob_ud_ = 'none'
   --             SET @record
   --                 = RTRIM(@record) + SPACE(15) + @tab + SPACE(50) + @tab + SPACE(50) + @tab + SPACE(50) + @tab;
   --         ELSE
   --             SET @record = RTRIM(@record) + SPACE(15) + @tab + @eob_ud + @tab + @eob_nm + @tab + SPACE(50) + @tab; -- Joe 10/23/2024

   --         -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits   
   --         SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
   --         SET @record = RTRIM(@record);
   --         SET @reclen = LEN(@record);

   --         DELETE FROM @serviceLineAdjustmentsTable;

   --         INSERT INTO @serviceLineAdjustmentsTable
   --         SELECT @recordType,                           --    cRecordType                                
   --                @recordVersion,                        -- 	cRecordVersion
   --                ISNULL(@doc_id, ''),                   -- 	cDocId
   --                ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
   --                ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
   --                ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
   --                ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
   --                ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
   --                '',                                    -- 	cLabel	
   --                '',                                    -- 	cServiceQualifier			
   --                ISNULL(@cob_savings, 0),               -- 	cAdjustmentAmount		
   --                '',                                    -- 	cAdjustmentGroupCode ???		???	
   --                22,                                    -- 	cAdjustmentReasonCode
   --                ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
   --                ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
   --                ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
   --                '',                                    -- 	cAlternateProcedureCode
   --                ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
   --                ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
   --                '',                                    -- 	cOpenField3		
   --                '',                                    -- 	cOriginalChargeAmount
   --                '',                                    -- 	cOriginalLineNumber			   							
   --                '',                                    -- 	cOriginalUnits				   			
   --                '',                                    -- 	cClientSystemRemarkCode	   						
   --                '',                                    -- 	cAdjustmentReasonType										   							
   --                '',                                    -- 	cQuantity
   --                '',                                    -- 	cSvcRARC2
   --                '',                                    -- 	cSvcRARC3
   --                '',                                    -- 	cSvcRARC4
   --                '',                                    -- 	cSvcRARC5									   								
   --                '',                                    -- 	cSvcRARC6										   							
   --                '',                                    -- 	cSvcRARC7
   --                '',                                    -- 	cSvcRARC8
   --                '',                                    -- 	cSvcRARC9
   --                '';                                    -- 	cSvcRARC10						   					




   --         SET @record =
   --         (
   --             SELECT TOP 1
   --                    [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
   --                    + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
   --                    + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
   --                    + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
   --                    + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
   --                    + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
   --                    + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
   --                    + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
   --                    + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
   --                    + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
   --             FROM @serviceLineAdjustmentsTable
   --         );

			---- Save data fields and check run parameters 
			--EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			---- Insert Payment File Record
   --         EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

   --         IF @return_status <> 0
   --         BEGIN
   --             SET @error_message
   --                 = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835 record: '
   --                   + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
   --             EXEC [finance_error_log_insert] @error_message, @modified_user_id;
   --             RETURN @return_status;
   --         END;
   --     END;


        --KDW 20250424 add capitation line
        IF @capitation_amount <> 0
        BEGIN

            --set values as static
            SET @inelig_gc = 'CO';
            SET @inelig_arc = '24';
            SET @inelig_rarc = '';

            --    SET @record
            --     = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
            --       + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(@claim_ud))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            SET @adj_amount_char = CONVERT(VARCHAR(15), ISNULL(@capitation_amount, 0));
            -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + LEFT(@inelig_gc + SPACE(2),2) + @tab; -- modified 02/21/2018 put  adjustmentgroupcode  
            -- SET @record = RTRIM(@record) + @inelig_arc + SPACE(5 - LEN(RTRIM(@inelig_arc))) + @tab;
            -- SET @record = RTRIM(@record) + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
            --                                                                                           -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;



            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(50) + @tab + SPACE(50) + @tab + SPACE(50) + @tab;


            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   ISNULL(@capitation_amount, 0),         -- 	cAdjustmentAmount		
                   ISNULL(@inelig_gc, ''),                -- 	cAdjustmentGroupCode ???		???	
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10


			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;


            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;


        END;

        --KDW 20250424 add $0 adjustment -- Adding ABS to handle claim negates 46807
        IF ( ABS(ISNULL(@write_off_amount, 0)) + ABS(ISNULL(@copay, 0)) + ABS(ISNULL(@deductible, 0)) + ABS(ISNULL(@coinsurance, 0))
             + ABS(ISNULL(@cob_savings, 0)) + ABS(ISNULL(@msa_paid_amount, 0)) + ABS(ISNULL(@prior_payer_paid_amount, 0))
             + ABS(ISNULL(@inelig_PR, 0)) + ABS(ISNULL(@inelig_CO, 0)) + ABS(ISNULL(@inelig_PI, 0)) + ABS(ISNULL(@inelig_OA, 0))
             + ABS(ISNULL(@claim_ineligible_amount, 0)) + ABS(ISNULL(@capitation_amount, 0)) + ABS(ISNULL(@cas_adj, 0)) --KDW 20250424
           ) = 0
        BEGIN

            --PRINT 'in $0'
            --set values as static
            SET @inelig_gc = '';
            SET @inelig_arc = '';
            SET @inelig_rarc = '';

            --    SET @record
            --     = '32' + @tab + '02' + @tab + @doc_id + @tab + @claim_sequence_char + @tab + @claim_ud
            --       + SPACE(25 - (LEN(RTRIM(@claim_ud)))) + @tab;

            SET @servicelinesequence = @servicelinesequence + 1;

            -- the count of the service lines on the claim procedrue  
            SET @servicelinesequence_char = CONVERT(CHAR(6), @servicelinesequence);
            SELECT @servicelinesequence_char
                = REPLICATE('0', 6 - LEN(@servicelinesequence_char)) + @servicelinesequence_char;

            -- the line number of the claim procedure benefit detail   
            SET @servicelinenumber_char = CONVERT(CHAR(3), @servicelinenumber);
            SELECT @servicelinenumber_char = REPLICATE('0', 3 - LEN(@servicelinenumber_char)) + @servicelinenumber_char;
            -- for claim relationship it is claim_ud   
            --SET @record
            --    = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab + @claim_ud
            --      + SPACE(50 - (LEN(@claim_ud))) + @tab;
            SET @claimrelationship_char = CONVERT(CHAR(50), @claim_ud);
            -- SET @record
            --     = RTRIM(@record) + @servicelinesequence_char + @tab + @servicelinenumber_char + @tab
            --       + @claimrelationship_char + @tab; -- Joe 12/27/2024

            -- -- cLabel,cServiceQualifier  
            -- SET @record = RTRIM(@record) + SPACE(25) + @tab + SPACE(2) + @tab;

            -- now determine service adjustment amount, Service Line Adjustment Group Code,  
            --SET @adj_amount_char = CONVERT(VARCHAR(15), 0);  --KDW 20250804
            -- cAdjustmentAmount,cAdjustmentGroupCode  
            -- SET @record = RTRIM(@record) + @adj_amount_char + @tab + LEFT(@inelig_gc + SPACE(2),2) + @tab; -- modified 02/21/2018 put  adjustmentgroupcode  
            -- SET @record = RTRIM(@record) + @inelig_arc + SPACE(5 - LEN(RTRIM(@inelig_arc))) + @tab;
            -- SET @record = RTRIM(@record) + @inelig_rarc + SPACE(5 - LEN(RTRIM(@inelig_rarc))) + @tab; -- modified 02/21/2018 pass rarc  
            --                                                                                           -- cLineItemControlNumber, ELVA 03/26/2018 add the linecontrol number  
            -- SET @record
            --     = RTRIM(@record) + CONVERT(VARCHAR, @2400_REF_6R)
            --       + SPACE(50 - (LEN(RTRIM(CONVERT(VARCHAR, @2400_REF_6R))))) + @tab;
            -- --cOriginalProcedureCode  
            -- SET @record = RTRIM(@record) + @procedure_code_ud + SPACE(10 - (LEN(RTRIM(@procedure_code_ud)))) + @tab;



            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(50) + @tab + SPACE(50) + @tab + SPACE(50) + @tab;


            -- -- cOriginalChargeAmount,cOriginalLineNumber,cOriginalUnits  
            -- SET @record = RTRIM(@record) + SPACE(15) + @tab + SPACE(15) + @tab + SPACE(10) + @tab;
            -- SET @record = RTRIM(@record);
            -- SET @reclen = LEN(@record);

            DELETE FROM @serviceLineAdjustmentsTable;

            INSERT INTO @serviceLineAdjustmentsTable
            SELECT @recordType,                           --    cRecordType                                
                   @recordVersion,                        -- 	cRecordVersion
                   ISNULL(@doc_id, ''),                   -- 	cDocId
                   ISNULL(@claim_sequence_char, ''),      -- 	cClaimSequence
                   ISNULL(@claim_ud, ''),                 -- 	cClaimNumber
                   ISNULL(@servicelinesequence_char, ''), -- 	cServiceLineSequence	
                   ISNULL(@servicelinenumber_char, ''),   -- 	cLineNumber
                   ISNULL(@claim_ud, ''),                 -- 	cClaimRelationString		
                   '',                                    -- 	cLabel	
                   '',                                    -- 	cServiceQualifier			
                   0,                                     -- 	cAdjustmentAmount		
                   ISNULL(@inelig_gc, ''),                -- 	cAdjustmentGroupCode ???		???	
                   ISNULL(@inelig_arc, ''),               -- 	cAdjustmentReasonCode
                   ISNULL(@inelig_rarc, ''),              --    cSvcRARC @verify
                   ISNULL(@2400_REF_6R, ''),              -- 	cLineItemControlNumber				
                   ISNULL(@procedure_code_ud, ''),        -- 	cOriginalProcedureCode			
                   '',                                    -- 	cAlternateProcedureCode
                   ISNULL(@eob_ud_, ''),                  -- 	cOpenField1		
                   ISNULL(@eob_nm_, ''),                  -- 	cOpenField2			
                   '',                                    -- 	cOpenField3		
                   '',                                    -- 	cOriginalChargeAmount
                   '',                                    -- 	cOriginalLineNumber			   							
                   '',                                    -- 	cOriginalUnits				   			
                   '',                                    -- 	cClientSystemRemarkCode	   						
                   '',                                    -- 	cAdjustmentReasonType										   							
                   '',                                    -- 	cQuantity
                   '',                                    -- 	cSvcRARC2
                   '',                                    -- 	cSvcRARC3
                   '',                                    -- 	cSvcRARC4
                   '',                                    -- 	cSvcRARC5									   								
                   '',                                    -- 	cSvcRARC6										   							
                   '',                                    -- 	cSvcRARC7
                   '',                                    -- 	cSvcRARC8
                   '',                                    -- 	cSvcRARC9
                   '';                                    -- 	cSvcRARC10						   					




            SET @record =
            (
                SELECT TOP 1
                       [cRecordType] + @tab + [cRecordVersion] + @tab + [cDocId] + @tab + [cClaimSequence] + @tab
                       + [cClaimNumber] + @tab + [cServiceLineSequence] + @tab + [cLineNumber] + @tab
                       + [cClaimRelationString] + @tab + [cLabel] + @tab + [cServiceQualifier] + @tab
                       + [cAdjustmentAmount] + @tab + [cAdjustmentGroupCode] + @tab + [cAdjustmentReasonCode] + @tab
                       + [cSvcRARC] + @tab + [cLineItemControlNumber] + @tab + [cOriginalProcedureCode] + @tab
                       + [cAlternateProcedureCode] + @tab + [cOpenField1] + @tab + [cOpenField2] + @tab + [cOpenField3]
                       + @tab + [cOriginalChargeAmount] + @tab + [cOriginalLineNumber] + @tab + [cOriginalUnits] + @tab
                       + [cClientSystemRemarkCode] + @tab + [cAdjustmentReasonType] + @tab + [cQuantity] + @tab
                       + [cSvcRARC2] + @tab + [cSvcRARC3] + @tab + [cSvcRARC4] + @tab + [cSvcRARC5] + @tab + [cSvcRARC6]
                       + @tab + [cSvcRARC7] + @tab + [cSvcRARC8] + @tab + [cSvcRARC9] + @tab + [cSvcRARC10] + @tab
                FROM @serviceLineAdjustmentsTable
            );

 			-- Save data fields and check run parameters 
			EXEC [dbo].[check_run_32_ServiceLineAdjustments_log_redcard] @check_run_id, @voucher_id, @claim_id, @claim_ud, @doc_type, @doc_id, @suppress_eop, @serviceLineAdjustmentsTable

			-- Insert Payment File Record
            EXEC @return_status = [dbo].[check_run_record_insert_redcard] @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id;

            IF @return_status <> 0
            BEGIN
                SET @error_message
                    = 'An error in check_run_servicelineadj835_redcard.check_run_record_insert_redcard has occured with servicelineadj835record: '
                      + ISNULL(@record, 'null') + ' : claim_id : ' + CONVERT(VARCHAR, ISNULL(@claim_id, 0));
                EXEC [finance_error_log_insert] @error_message, @modified_user_id;
                RETURN @return_status;
            END;

        END;

        SET @record_id = @record_id + 1;
    END;

    -- Process overpayment netting - 04/30/2025
    --IF @enable_netting = 1
    --BEGIN

    --    EXEC [dbo].[check_run_serviceline_netting_redcard] @check_run_id = @check_run_id,
    --                                                       @claim_id = @claim_id,
    --                                                       @claim_ud = @claim_ud,
    --                                                       @doc_id = @doc_id,
    --                                                       @doc_type = @doc_type,
    --                                                       @claim_sequence = @claim_sequence,
    --                                                       @servicelinesequence = @servicelinesequence,
    --                                                       @servicelinenumber = @servicelinenumber,
    --                                                       @voucher_id = @voucher_id,
    --                                                       @line_number = @line_number OUTPUT;
    --END;

END TRY
BEGIN CATCH
    SET @error_message
        = @error_message + 'Error in step ' + ': Error number ' + CAST(ERROR_NUMBER() AS VARCHAR) + ' at line '
          + CAST(ERROR_LINE() AS VARCHAR) + ': ' + ERROR_MESSAGE();
    SET @return_status = -1;
    SET @Email_Subject = 'check_run_servicelineadj835_redcard fatal error ';
    SET @Email_Body = @error_message;
    --set @return_message = 'The following source directory is missing. "' + coalesce(@source_directory_path, '') + '"'  
    RAISERROR(@error_message, 15, 1);
    -----------------------------------------------
    --SENDING EMAIL --MODIFIED by MikeZharov 6/17/2022, 
    --------------------------------------------------
    --SET @Notif_to = 'qizhi.zhu@webtpa.com';
    --SET @Notif_cc = 'qizhi.zhu@webtpa.com';
    EXEC [msdb].[dbo].[sp_send_dbmail] @recipients = @Notif_to,            -- varchar(max)
                                       @copy_recipients = @Notif_cc,       -- varchar(max)
                                       @subject = @Email_Subject,          -- nvarchar(255)
                                       @body = @Email_Body,                -- nvarchar(max)
                                       @body_format = @Email_Format,       -- varchar(20)
                                       @importance = @Email_Importance,    -- varchar(6)
                                       @mailitem_id = @mailitem_id OUTPUT, -- int
                                       @from_address = @Notif_from;        -- varchar(max)



    --SET @recipients2 = 'qizhi.zhu@webtpa.com';
    EXEC [msdb].[dbo].[sp_send_dbmail] @recipients = @recipients2,          -- varchar(max)
                                       @copy_recipients = @Notif_cc,        -- varchar(max)
                                       @subject = @Email_Subject,           -- nvarchar(255)
                                       @body = @Email_Body,                 -- nvarchar(max)
                                       @body_format = @Email_Format,        -- varchar(20)
                                       @importance = @Email_Importance,     -- varchar(6)
                                       @mailitem_id = @mailitem_id2 OUTPUT, -- int
                                       @from_address = @Notif_from;         -- varchar(max)

    ----------------------------------
    ---------------------------------- 
    RETURN @return_status;
END CATCH;

RETURN @return_status;
