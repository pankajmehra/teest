USE [mcr_dc_prod]
GO

/****** Object: StoredProcedure [dbo].[usp_adj_L10_check_for_COB] Script Date: 8/24/2026 10:23:34 AM ******/

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[usp_adj_L10_check_for_COB] (
    @claim_procedure_id int
    , @member_id int
    , @from_date smalldatetime
    , @to_date smalldatetime
    , @adj_test_number int OUTPUT
)
AS

SET NOCOUNT ON

/**************************************
Change History:
US#46386 - Remove 406 edit for claims where "Auto" or "Other Accident"
           is selected under Condition Related To. All other 406 logic
           remains unchanged.

Co-ordination of benefits is required if
- the claim procedure line has the COB bit set
- the member has a Medicare, Medicaid, Champus, or other identifier defined
- the member has a COB record for an accident/injury that is in effect for the dates of service
**************************************/

DECLARE
    @return_status int
    , @error int

SET @return_status = 0
SET @adj_test_number = NULL

/******************************
First check if the COB bit is set on the claim procedure line
*******************************/
IF EXISTS (
    SELECT cob
    FROM claim_procedure (NOLOCK)
    WHERE cob = 1
      AND claim_procedure_id = @claim_procedure_id
)
    GOTO COB_Needed

/******************************
US#46386
Do not stop the claim for 406 solely because rel_to_auto or
rel_to_other is selected. Employment and Other Plan continue
to follow the existing 406 logic.
*******************************/
IF EXISTS (
    SELECT *
    FROM claim (NOLOCK)
    INNER JOIN claim_procedure
        ON claim.claim_id = claim_procedure.claim_id
    WHERE (
        rel_to_employment = 1
        OR other_plan = 1
    )
      AND claim_procedure_id = @claim_procedure_id
)
    GOTO COB_Needed

/******************************
Next check if any COB type id is set for this member
*******************************/
IF EXISTS (
    SELECT *
    FROM member_id_map (NOLOCK)
    WHERE member_id = @member_id
)
    GOTO COB_Needed

/*****************************
Next check for any accident/injury etc COB records that are active
on the dates of service
******************************/
IF EXISTS (
    SELECT member_cob_id
    FROM member_cob (NOLOCK)
    WHERE member_id = @member_id
      AND eff_date <= @from_date
      AND (term_date >= @to_date OR term_date IS NULL)
)
    GOTO COB_Needed

RETURN 0

COB_Needed:

SELECT @adj_test_number = 14

RETURN -100 /* HOLD */
GO
