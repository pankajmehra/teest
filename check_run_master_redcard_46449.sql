USE [mcr_dc_prod]
GO
/****** Object:  StoredProcedure [dbo].[check_run_master_redcard]    Script Date: 8/3/2026 10:13:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[check_run_master_redcard] 
 @check_run_id [int],  
 @modified_user_id [int],  
 @voucher_payment_rule_id [int],  
 @check_run_account_header_id [int] output,   
 @last_checkbook_id  [int] output ,   
 @checkbook_id [int],   
 @doc_type char(3),   
 @doccounter [int] output,  
 @doc_id  [CHAR] (25)  OUTPUT,  
 @line_number [int] OUTPUT,  
 @correspondence_id int  ,  
 @record_type varchar(50) ,  
 @cor_name varchar(50),   
 @primary_correspondence_link_type_id int
  
WITH EXECUTE AS CALLER
AS  
/** ---------------------------------------------------------------------------------------------------------  
 -- This stored procedure creates the master delivery and master extension record types. It is a tab delimited file.  
 -- One master record for each voucher_payment_rule and one voucher_payment_rule for each voucher.   
 -- For correspondence, one master record for each correspondence id   
   
 Master Delivery Record
 ----------------------
 Record Layout details: J:\Documentation\ScrumTeams\Finance\Zelis\Payment File Format Report 20231113.pdf
 Record Type: 00
 Record Version: 64
 Total Length: 5202  
  
  
 Master Extension Record 
 -----------------------
 Record Layout details: J:\Documentation\ScrumTeams\Finance\Zelis\Payment File Format Report 20231113.pdf
 Record Type: 16
 Record Version: 07
 Total Length: 839
  
 Modified 09/09/2016 when the subscriber or member id changed on the claim, and they were all on the same voucher I was not setting the check_run_eob_header to null and creating a new one.  
 Modified 03/09/2017 When multiple EOB's are printed on one voucher I was putting all remarks on the last EOB instead of putting each EOB's remarks on it.   
 Modified 04/18/2017 pass manual_ap_entry.attention_line in masterDelivery.cname2  
 Modified 01/29/2018 pass checkbook_check_id as barcode  
 Modified 03/18/2018 by jjt determine whether to include copay as member obligation  
 Modified 06/08/2018 by elva I wasn't populating address name for manual checks if it was a member payment  
 Modified 06/22/2018 we need to pass the voucher_payment_id for the barcode instead of the checkbook_check_id. This way no pays and zero dollar vouchers will also have a barcode  
 Modified 09/26/2018 a members zip was only 4 chars so modified to add a space at the end  
 Modified 11/27/2018 if claim_type 12 MEDICAID HCFA,13 MEDICAID UB92,18 MEDICAID DENTAL never print a eob  
 Modified 01/23/2019 follow same rules for correspondence as for eob on member_privacy_type_id  and removed nolocks  
 Modified 05/07/2019 attendtion line had one charcter too many   
 Modified 10/30/2019 modified for nextera to have different processing rules.  provider no pays will still go to the print vendor for eops' but no other provider documents will go.  not eop's, checks or correspondence.   
 Modified 12/06/2019 modified for nextera the check records were still getting created   
 Modified 01/23/2019 Nextera does want to print Pesrenal - Provider end stage renal disease form.  
 Modified 05/07/2020 for manual checks we were setting cRecipientCode to o .  Vpay says it is used for vendors but for members we must pass I.  
 Modified 08/19/2021 Flagler checkbook id 1343 and check_run_community_id 55 BCBS Funding will process the same as Nextera, checkbook id 1300 and check run community 50.  
 Modified 04/11/2022 elva - a dependant had the address set up except for zip so created and error with a null insert on correspondence capture the subscriber address all the time.   
 Modified 06/13/2022 mike - updated recipients ticket 12032  
 Modified 06/17/2022 mike - updated email from table ticket 12292  
 Modified 11/03/2022 (SN) - adding 58 UMM Straight to Check and 57 UMM Funding to check_run_community_id
 Modified 05/22/2023 (SN) - Prudential eob suppression and eop suppression story 19478 checkbook id 1427 based on eob codes (3906 suppress eob), (3292 suppress eob, and eop and all correspondence) 
 Modified 06/02/2023 elva - we can't suppress the eop on 3292 , I didn't realize it until we hit the correct data in production 
 Modified 01/26/2024 elva - Baptist Health Pensecolar checkbook id 1575, is a new Florida Blue Group.  They do want the no pay's suppressed
 Modified 02/28/2024 elva - add ach choice for member eob's.  If it is an ach even though check_attached for member = 1 don't do a check
 Modified 03/05/2024 elva - for correspondence if the emmployergroup does not have a return address set up look and see if the parent_employergroup does
 Modified 03/19/2024 elva - pass a Y/N for Erisa in the cOpenField2 field 
 Modified 04/5/2024  PS   - if there is an address found in correspondence record use that intead of member's 
 Modified 06/07/2024 mjp  - performance add temp table for eob suppression check
 Modified 06/11/2024 elva - modification for vendor letters c.correspondence_type_id in (11,83,114,115) W9, B Notice One, B Notice Two 
 Modified 07/25/2024 jjt  - Added criteria for #claim_info for c.correspondence_type_id in (11,83,114,115) W9, B Notice One, B Notice Two, to prevent duplicating detail lines in free form letters.
 Modified 12/31/2024 PS   - Added new Check Run Community for Florida Blue OOS (62) in list of no_pay (suppresed) claims 
 Modified 01/16/2025 Joe  #39265 - pass @claim_id to check process for venfor feb tax id and vendor npi
 Modified 03/04/2025 Juan #36694 - Update Default Return Address Name from WEBTPA, INC. to WebTPA Employer Services
 Modified 03/11/2025 PS #40041 - Passing Underwriting Company Name in cOpenField3
 Modified 06/16/2025 PS #41365 - Updating Master Extension layout to version 61 and using a table structure to generate record string. Each record will be saved to dbo.check_run_00_masterdelivery table 
 Modified 07/09/2025 SP #41961 - Updating MasterExtension1 to version 07.
 Modified 09/22/2025 AJ #43082 - commenting the condition of overpayment until we have a process to handle manual overpayments
 Modified 11/25/2025 PS #43847 - Updating checkbook_check.alt_check_number with disbursement id on Anthem check payments 
 Modified 01/06/2025 PM #44604 - Anthem | Map new Anthem QPA EOB Codes to trigger the NSA/DIS code in the Check Run File | Prod Ticket #48722
 Modified 01/06/2025 SP #44757 - Add suppression of EOP and provider payment to Community Anthem JAA (64) and medica UHC (65)
 Modified 03/09/2025 PM #45558 - FIN | Zelis Updates | QPA EOB Codes to trigger the NSA/DIS code in the Check Run File | Add Reliant
 Modified 03/10/2026 PS #45512 - Suppressing EOB for claims with repricing flag 640 'ANTHEM REJECT ACTION CODE'
 Modified 05/22/2026 JEM #46648 - FIN | WebTPA Physical Address | Update to include Suite 100 - Master Record
 Modified 06/24/2026 PS  46972 adding claim reversals on EOPs for Medica Non-UHC groups (M0004 through M0007)
 Modified 07/21/2026 PS  47283 allow claim reversals on EOPs for all groups
 Modified 08/04/2026 PM  46449 Populate Payee NPI in Master Record for claim-based documents

---------------------------------------------------------------------------------------------------------------------------------------------**/  
-- Local Variables  
----------------------------------------  

 DECLARE @return_status    int  
 DECLARE @record      CHAR(5202)  
 DECLARE @recext      char(839)      
 DECLARE @reclen      int  
 DECLARE @tab      char  
 DECLARE @fd       char  
 DECLARE @fq       char  
      
 DECLARE @work_amount    money  -- elva added 09/02/2011  
 DECLARE @work_int     int   -- elva added 09/02/2011  
 DECLARE @workfield     varchar(6) -- the character counter of docid   
 DECLARE @eob_remark_code_id        int  -- copied from check_run_eop]  
 DECLARE @created_eop_header        int  -- copied from check_run_eop]  
 DECLARE @barcode     varchar(50)  -- elva 01/29/2018  
  
 DECLARE @record_count    int   
 DECLARE @record_id     int    
 DECLARE @claim_type     varchar(50)  
 DECLARE @redcard_claim_type varchar(3)  
 
 -- Voucher Information  
 DECLARE @checkbook_rule_id         int  
 DECLARE @claim_redirect_rule_id  int  -- elva added 12/20/2012  
 DECLARE @voucher_id                int  
 DECLARE @manual_check_voucher      int  
 DECLARE @voucher_number            int  
 DECLARE @voucher_member_id         int  
 DECLARE @subscriber_member_id      int  
 DECLARE @vendor_id       int  
 DECLARE @no_pay                    int  
 DECLARE @voucher_status_id         int  
 DECLARE @amount_payable            money  
 DECLARE @voucher_created_date      datetime  
 DECLARE @voucher_payment_type_id   int  
 DECLARE @voucher_payment_id   int  
 DECLARE @checkbook_check_id        int  
 DECLARE @redirect                  bit  
 DECLARE @ACH						bit			-- elva 02/28/2024 
 DECLARE @voucher_number_char  char(16)  
  
 --EOB Values  
 DECLARE @check_attached_for_member bit  
 DECLARE @claim_line_sequence       int  
 DECLARE @eob_claim_count           int  
 DECLARE @eob_procedure_count          int  
 DECLARE @eob_number                char(15)  -- this is the correspondence id basically   
 DECLARE @claim_procedure_attachment_id int  
 DECLARE @attachment_name           varchar(50)  
 DECLARE @check_run_attachment_id   int   
 DECLARE @eop_number       char(15)  -- this is the correspondence id basically   
  
 -- Vendor Indormation  
 DECLARE @vendor_ud                 varchar(35)  
 DECLARE @vendor_tax_id             varchar(11)  
 DECLARE @vendor_name               varchar(80)  
 DECLARE @vendor_address1           varchar(80)  
 DECLARE @vendor_address2           varchar(80)  
 DECLARE @vendor_city               varchar(30)  
 DECLARE @vendor_state              varchar(2)  
 DECLARE @vendor_zip                varchar(5)  
 DECLARE @vendor_phone              varchar(13)  
 DECLARE @payee_npi                 varchar(10) -- 46449
  
 -- Check Information  
 DECLARE @check_number              bigint  
 DECLARE @check_date                datetime  
 DECLARE @check_amount              money  
 DECLARE @check_name                varchar(80)  
 DECLARE @check_address1            varchar(80)  
 DECLARE @check_address2            varchar(80)  
 DECLARE @check_city                varchar(30)  
 DECLARE @check_state               varchar(2)  
 DECLARE @check_zip                 varchar(5)  
  
 -- Carrier Information  
 DECLARE @carrier_name    varchar(50)  
 DECLARE @group_contract_id   int  
  
 -- Claim Information  
 DECLARE @claim_id                  int  
 DECLARE @corr_claim_id				int		-- SN 05/23/2023 claim id linked to correspondence record
 DECLARE @claim_ud                  varchar(20)  
 DECLARE @claim_type_id      int  -- elva 11/27/2018  
 DECLARE @revision_number           int  
 DECLARE @service_from_date         datetime  
 DECLARE @service_to_date           datetime  
 DECLARE @patient_number            varchar(15)  
 DECLARE @provider_id               int  
 DECLARE @provider_ud               varchar(35)  
 DECLARE @provider_name             varchar(71)  
 DECLARE @provider_last_name        varchar(35)  
 DECLARE @provider_first_name       varchar(35)  
  
 -- Addressee Information  
 DECLARE @addressee_name            varchar(80)  
 DECLARE @addressee_last_name       varchar(35)  
 DECLARE @addressee_first_name      varchar(35)  
 DECLARE @addressee_ssn             varchar(11)  
 DECLARE @addressee_address1        varchar(80)  
 DECLARE @addressee_address2        varchar(80)  
 DECLARE @addressee_city            varchar(30)  
 DECLARE @addressee_state           varchar(2)  
 DECLARE @addressee_zip             varchar(5)  
 DECLARE @addressee_phone           varchar(12)   
 DECLARE @addressee_attn    varchar(45)  -- elva 04/18/2017  
    
 -- Member Information  
 DECLARE @member_name               varchar(80)  
 DECLARE @member_last_name          varchar(35)  
 DECLARE @member_first_name         varchar(35)  
 DECLARE @member_alt_last_name      varchar(35)  
 DECLARE @member_alt_first_name     varchar(35)  
 DECLARE @member_ssn                varchar(15)  
 DECLARE @member_address1           varchar(80)  
 DECLARE @member_address2           varchar(80)  
 DECLARE @member_city               varchar(30)  
 DECLARE @member_state              varchar(2)  
 DECLARE @member_zip                varchar(5)  
 DECLARE @member_phone              varchar(13)  
 DECLARE @member_eligibility_ud     varchar(35)  
 DECLARE @guardian_name             varchar(71)  
 DECLARE @member_privacy_type_id    int  
  
 -- Subscriber Information  
 DECLARE @subscriber_id             int  
 DECLARE @subscriber_name           varchar(80)  
 DECLARE @subscriber_last_name      varchar(35)  
 DECLARE @subscriber_first_name     varchar(35)  
 DECLARE @subscriber_ssn            varchar(11)  
 DECLARE @subscriber_address1       varchar(80)  
 DECLARE @subscriber_address2       varchar(80)  
 DECLARE @subscriber_city           varchar(30)  
 DECLARE @subscriber_state          varchar(2)  
 DECLARE @subscriber_zip            varchar(5)  
 DECLARE @subscriber_phone          varchar(13)  
 DECLARE @subscriber_group          varchar(35)  
 DECLARE @subscriber_group_name     varchar(50)  
 DECLARE @subscriber_plan           varchar(50)  
 DECLARE @ERISA                     bit   
 DECLARE @policy_origination_state    varchar(2)  
  
 -- Bank Information  
 DECLARE @bank_config_id    int  
 DECLARE @bank_id     int  
 DECLARE @bank_name     varchar(50)  
 DECLARE @routing_number    varchar(50)  
 DECLARE @bank_address1    varchar(50)  
 DECLARE @bank_address2    varchar(50)  
 DECLARE @bank_city     varchar(50)  
 DECLARE @bank_state     char(2)  
 DECLARE @bank_zip     varchar(50)  
  
 -- Return Address  
 DECLARE @contact_address_id   int  
 DECLARE @return_name    varchar(50)  
 DECLARE @return_address1   varchar(50)  
 DECLARE @return_address2   varchar(50)  
 DECLARE @return_city    varchar(30)  
 DECLARE @return_state    varchar(2)  
 DECLARE @return_zip     varchar(5)  
 DECLARE @return_phone    varchar(50)  
 DECLARE @return_fax     varchar(50)  
 DECLARE @parent_employergroup_id int
  
 -- Redirection Information  
 DECLARE @redirection_name   varchar(50)  
 DECLARE @redirection_address1  varchar(50)  
 DECLARE @redirection_address2  varchar(50)  
 DECLARE @redirection_city   varchar(50)  
 DECLARE @redirection_state   varchar(2)  
 DECLARE @redirection_zip   varchar(50)  
 DECLARE @redirection_phone   varchar(50)  
 DECLARE @redirection_reason   varchar(80)  
 DECLARE @redirection_method   varchar(80)  
 DECLARE @redirect_code    char(3)  
  
 -- In claim non detail record   
 DECLARE @claim_member_id           int  
 DECLARE @claim_subscriber_member_id int  
 DECLARE @last_member_id            int  
 DECLARE @last_subscriber_id        int  
 DECLARE @last_claim_id    int   
 DECLARE @claim_sequence      int   
  
  
 -- Checkbook Information  
 DECLARE @checkbook_config_id  int  
 DECLARE @checkbook_name    varchar(50)  
 DECLARE @account_number    varchar(50)  
 DECLARE @check_stock    varchar(25)  
 DECLARE @signatures_required  int  
 DECLARE @check_run_community_id  int   -- elva 10/30/2019  
 
 -- Accumulator Information  
 DECLARE @print_accumulators_on_eob  bit  
 DECLARE @employergroup_id   int  
 DECLARE @benefitplan_id    int  
 DECLARE @VISIT_TYPE     int  
 
 DECLARE @NSA_flag BIT = 0
 DECLARE @EEC_flag BIT = 0
 DECLARE @EEC_ub_flag BIT = 0
 DECLARE @QPA_IDR_Trigger VARCHAR(3)

 -- Error log and emails   
 DECLARE @error_message    varchar(2000)  

 --------------------------------------------------------------------------------------------------  
 -- EMAIL & LOGGING INFORMATION   
 ------------------------------------------------------------------------------------------------  
  DECLARE @user_id INT       
  DECLARE @start INT    
  DECLARE @login_name VARCHAR(50)    
  
  SELECT @start = charindex('\',suser_sname())    
  SELECT @login_name = substring(suser_sname(),@start+1,len(suser_sname())-@start)      
  SELECT @user_id = sec_user_id FROM [dbo].[sec_user] WHERE login_name = @login_name 
  SELECT @user_id = ISNULL(@user_id, 0) --system 
  
  DECLARE @server       VARCHAR(50) = (SELECT @@SERVERNAME)
  DECLARE @sp_name      VARCHAR(100) = (SELECT object_name(@@PROCID))
  DECLARE @ProgramName  VARCHAR(100) = 'CheckRun_Redcard';  
 -------------------------------------------------------------------------------------------------------------  
  
 -- EOB Suppression  
 DECLARE @suppress_checkbook   BIT  
 DECLARE @suppress_eop    BIT  
 DECLARE @suppress_copay    MONEY  
 DECLARE @suppress_coinsurance  MONEY  
 DECLARE @suppress_ineligible  MONEY  
 DECLARE @suppress_deductible  MONEY  
 DECLARE @force_to_print    BIT  
 DECLARE @suppress_member_obligation BIT  
 DECLARE @suppress_this_claim  BIT  
 DECLARE @suppress_eob    BIT  
 DECLARE @save_suppress_eob   bit  
 DECLARE @include_copay_in_member_obligation bit  
  
 DECLARE @check_run_eop_claim_id  INT  
 DECLARE @check_run_eop_claim_procedure_id INT  
  
 DECLARE @check_run_eob_header_id INT  
 DECLARE @check_run_eop_header_id int  
 --DECLARE @check_run_account_header_id int  
 --DECLARE @doc_type char(3)  
  
 DECLARE  @created_master_record  bit -- flag to know when we need a new created record   
 DECLARE  @first_claim    bit -- flag to know when to start @claim_sequence at 0  
 DECLARE @first_time     bit   
  
 DECLARE @manual_number             char(15)  
  
 DECLARE @servicelinesequence  int   
  
 DECLARE @correspondence_type_id  int   
 DECLARE @manual_ap_entry_id   int   
 DECLARE @crecipientcode    char(1)  
 DECLARE @cDocumentType CHAR(3)

 -- in claim non detail record  
 create table #claiminfo (  
 claiminfo_id int identity not null,  
 claim_id int ,   
 member_id int,   
 subscriber_id int,   
 group_contract_id int,  
 subscriber_last_name varchar(35),   
 subscriber_first_name varchar(35),  
 member_last_name varchar(35),  
 member_first_name varchar(35),  
 correspondence_id int,   
 manual_ap_entry_id int)  
 create index idx_claiminfo_claim_id  on #claiminfo(claim_id)
-- mjp 06/07/2024 start
drop table if exists #temp_member_eligibility
create table #temp_member_eligibility(eligibility_id int)
-- mjp 06/07/2024 end

 -- Add attachments to EOB  
 DECLARE @attachment_code   VARCHAR(3)  
  
    -----------------------------------------------  
    -- Initialize Variables  
    -----------------------------------------------  
    SET @return_status = 0  
    SET @last_member_id = 0  
    SET @last_subscriber_id = 0  
 set @save_suppress_eob = 0  
 set @last_claim_id = 0   
    SET @check_attached_for_member = 0   
 SET @carrier_name = NULL  
 set @fd = ','  
 set @fq = '"'  
 set @tab = CHAR(9)  
 set @addressee_attn = ''  -- 04/18/2017  
  
  
 DECLARE @suppress_claims TABLE (   
  claim_id int primary key  
 , suppress bit )  
  
begin try   
    -----------------------------------------------  
    -- Get Information About the Voucher Payment  
    -----------------------------------------------  
    SELECT @checkbook_rule_id = voucher_payment_rule.checkbook_rule_id,  
  @claim_redirect_rule_id =  voucher_payment_rule.claim_redirect_rule_id ,  
           @voucher_id = voucher.voucher_id,  
           @voucher_number = voucher.voucher_number,  
     @manual_check_voucher = voucher.manual_check_voucher,  
           @voucher_member_id = voucher.member_id,  
     @subscriber_member_id = voucher.subscriber_member_id,  
           @vendor_id = voucher.vendor_id,  
           @no_pay = voucher.no_pay,  
           @voucher_status_id = voucher.voucher_status_id,  
           @amount_payable = voucher.amount_payable,  
           @voucher_created_date = voucher.created_date,  
           @voucher_payment_type_id = voucher_payment.voucher_payment_type_id,  
           @voucher_payment_id = voucher_payment.voucher_payment_id,  
           @checkbook_check_id = voucher_payment.checkbook_check_id ,
		   @ach = voucher.ach			-- elva 02/28/2024
      FROM voucher  
      JOIN voucher_payment  
        ON voucher_payment.voucher_id = voucher.voucher_id  
      JOIN voucher_payment_rule  
        ON voucher_payment_rule.voucher_payment_id = voucher_payment.voucher_payment_id  
     WHERE voucher_payment_rule.voucher_payment_rule_id = @voucher_payment_rule_id  
  
 set @voucher_number_char = convert(char(16), @voucher_number)   
 -- set barcode to voucher_payment_id not checkbook_check_id elva 06/22/2018  
 if isnull(@voucher_payment_id,0) = 0  
  set @barcode =  ''  
 else   
  set @barcode = convert(char(50),isnull(@voucher_payment_id,0))  -- elva 01/26/2018  
  
 IF @checkbook_rule_id IS NULL AND @claim_redirect_rule_id is null -- elva 12/20/2012  
 SET @redirect = 0 ELSE SET @redirect = 1  
  
 -- Checkbook General Information  
 select   
  @checkbook_config_id = checkbook_config.checkbook_config_id  
 , @checkbook_name = checkbook_config.payorname   
 , @account_number = ba.account_number --JRR 2015-12-16  
 , @signatures_required = checkbook_config.signatures_required  
 , @check_stock = checkbook_config.check_stock  
 , @check_run_community_id = checkbook_config.check_run_community_id  -- 10/30/2019  
 from checkbook_config  
  inner join dbo.checkbook c on checkbook_config.checkbook_id = c.checkbook_id  
  inner join dbo.bank_account ba on c.bank_account_id = ba.bank_account_id  
 where checkbook_config.checkbook_id = @checkbook_id  
  and checkbook_config.deleted = 0  
  and start_date <= getdate()  
  and (end_date > getdate() or end_date IS NULL)  
  
  
 -- Return Address Information  
 -- if correspondence it has a default address and then uses the employergroup_contact return address  
 -- otherwise it uses the checkbook_config return address   
 if @doc_type = 'COR' -- correspondence   
  begin   
   -- set default s  
   -----------------------------------  
   -- Initialize variables  
   -----------------------------------  
   SET @return_name  = 'WebTPA Employer Services'  -- JC 03/04/2025 -- the default retunr address should be updated to WebTPA Employer Services instead of WEBTPA, INC.
   SET @return_address1 = 'PO BOX 1808'  
   SET @return_address2 = ''  
   SET @return_city  = 'GRAPEVINE '    
   SET @return_state  = 'TX'  
   SET @return_zip   = '76099-1808'  
   SET @return_phone  = '800-919-2432'  
   SET @return_fax   = '469-417-1973'  

    -- determine employergroup_id   
   SELECT   
    @employergroup_id = e.employergroup_id  
	,   @parent_employergroup_id = eg.parent_employergroup_id 
   , @correspondence_type_id = c.correspondence_type_id  
   , @primary_correspondence_link_type_id = c.primary_correspondence_link_type_id		-- elva 03/05/2024
   FROM  
    correspondence c   
    -- left joins because we need the correspondence type id below  
    LEFT JOIN correspondence_eligibility_link cml  ON c.correspondence_id = cml.correspondence_id and cml.deleted = 0  
    LEFT JOIN eligibility e  ON cml.eligibility_id = e.eligibility_id  
	left join employergroup eg on e.employergroup_id = eg.employergroup_id -- elva 03/05/2024
   WHERE  
    c.correspondence_id = @correspondence_id  
    --AND c.deleted = 0  -- sometimes we create W9s soft deleted so we can segregate them in separate check runs.  
   ORDER BY  
    cml.correspondence_eligibility_link_id  
   --------------------------------------------------------------------  
   -- Override our default return address if we have one.  
   -- Modified 02/08/2013 If their address is set up, but the fax number is not populated default to our default fax number elva  
   -- modified 03/05/2024 does the parent employergroup have a return address set up.  If so use it
   --------------------------------------------------------------------  
   IF @employergroup_id IS NOT NULL
		begin 
			if  EXISTS (  
				SELECT 1 FROM employergroup_contact ec   
					INNER JOIN employergroup_contact_type ect ON ec.employergroup_contact_type_id = ect.employergroup_contact_type_id  
				WHERE   
					ec.employergroup_id = @employergroup_id  
					AND ect.employergroup_contact_type_ud = 'Return Address'  
					AND last_name IS NOT NULL AND LEN(last_name) > 0  
					AND first_name IS NOT NULL AND LEN(first_name) > 0  
					AND address1 IS NOT NULL AND LEN(address1) > 0  
					AND city IS NOT NULL AND LEN(city) > 0  
					AND state IS NOT NULL AND LEN(state) > 0  
					AND zipcode IS NOT NULL AND LEN(zipcode) > 0  
					) 
					BEGIN  
						SELECT TOP 1  
						@return_name = first_name + ' ' + last_name  
						, @return_address1 = address1  
						, @return_address2 = COALESCE(address2,'')  
						, @return_city = city  
						, @return_state = state  
						, @return_zip  = zipcode  
						, @return_phone = REPLACE(REPLACE(REPLACE(COALESCE(phone,''),' ', ''),'(',''),')','-')  
						, @return_fax = REPLACE(REPLACE(REPLACE(COALESCE(fax,@return_fax),' ', ''),'(',''),')','-')  
      
						FROM employergroup_contact ec   
						INNER JOIN employergroup_contact_type ect ON ec.employergroup_contact_type_id = ect.employergroup_contact_type_id  
						WHERE   
						ec.employergroup_id = @employergroup_id  
						AND ect.employergroup_contact_type_ud = 'Return Address'  
						AND last_name IS NOT NULL AND LEN(last_name) > 0  
						AND first_name IS NOT NULL AND LEN(first_name) > 0  
						AND address1 IS NOT NULL AND LEN(address1) > 0  
						AND city IS NOT NULL AND LEN(city) > 0  
						AND state IS NOT NULL AND LEN(state) > 0  
						AND zipcode IS NOT NULL AND LEN(zipcode) > 0    
						ORDER BY ec.date_modified DESC  
					end 
		 else 
			begin 
				-- does the parent employergroup have address information to use elva 03/05/2024
				if  EXISTS (
					SELECT 1 FROM employergroup_contact ec 
						INNER JOIN employergroup_contact_type ect ON ec.employergroup_contact_type_id = ect.employergroup_contact_type_id
					WHERE 
						ec.employergroup_id = @parent_employergroup_id
						AND ect.employergroup_contact_type_ud = 'Return Address'
						AND last_name IS NOT NULL AND LEN(last_name) > 0
						AND first_name IS NOT NULL AND LEN(first_name) > 0
						AND address1 IS NOT NULL AND LEN(address1) > 0
						AND city IS NOT NULL AND LEN(city) > 0
						AND state IS NOT NULL AND LEN(state) > 0
						AND zipcode IS NOT NULL AND LEN(zipcode) > 0
						)	
					begin
						SELECT TOP 1
							@return_name	= first_name + ' ' + last_name
						,	@return_address1	= address1
						,	@return_address2	= COALESCE(address2,'')
						,	@return_city	= city
						,	@return_state	= state
						,	@return_zip		= zipcode
						,	@return_phone = REPLACE(REPLACE(REPLACE(COALESCE(phone,''),' ', ''),'(',''),')','-')
						,	@return_fax = REPLACE(REPLACE(REPLACE(COALESCE(fax,@return_fax),' ', ''),'(',''),')','-')
							
						FROM employergroup_contact ec 
							INNER JOIN employergroup_contact_type ect ON ec.employergroup_contact_type_id = ect.employergroup_contact_type_id
						WHERE 
							ec.employergroup_id = @parent_employergroup_id
							AND ect.employergroup_contact_type_ud = 'Return Address'
							AND last_name IS NOT NULL AND LEN(last_name) > 0
							AND first_name IS NOT NULL AND LEN(first_name) > 0
							AND address1 IS NOT NULL AND LEN(address1) > 0
							AND city IS NOT NULL AND LEN(city) > 0
							AND state IS NOT NULL AND LEN(state) > 0
							AND zipcode IS NOT NULL AND LEN(zipcode) > 0		
						ORDER BY ec.date_modified DESC

					end 
				end -- elva end of add 03/05/2024
  
     end   
   -------------------------------------------------------------------  
   -- Override the fax number for W9s  jjt 9/04/2014 per Sharon & Phyllis  
   --------------------------------------------------------------------  
   IF @correspondence_type_id IN ( 11,83 )   -- W9, W9 Penalty  
    OR @correspondence_type_id IN ( 114,115) -- B NOTICE ONE, B NOTICE TWO  
   BEGIN  
   
    SET @return_name  = 'WebTPA'  
    SET @return_address1 = 'PO BOX 2445'  
    SET @return_address2 = ''  
    SET @return_city  = 'GRAPEVINE '    
    SET @return_state  = 'TX'  
    SET @return_zip   = '76099-2445'  
    SET @return_phone  = '800-919-2432'  
    SET @return_fax   = '469-417-1975'  -- 1099, W9 fax inbox  
      
    
   END   
  end   
 else -- all other document tabes have a checkbook_id associated with them  
  begin   
   select   
    @contact_address_id = contact_address.contact_address_id  
   , @return_name =   
    case contact_address.recipient_type_id  
     when 1 then isnull(contact.company,'')  
     when 2 then left(rtrim(contact.first_name) + ' ' + contact.last_name,50)  
     when 3 then isnull(contact_address.recipient_name,'')  
    end  
   , @return_address1 = isnull(contact_address.address1,'')  
   , @return_address2 = isnull(contact_address.address2,'')  
   , @return_city = left(rtrim(isnull(contact_address.city,'')),30)  
   , @return_state = state.state_ud  
   , @return_zip = left(isnull(contact_address.zip,''),5)  
   , @return_phone = checkbook_config.customer_service_phone  
   from contact  
    inner join contact_address on contact_address.contact_id = contact.contact_id   
     and contact_address.is_default = 1   
     and contact_address.deleted = 0  
    inner join state on contact_address.state_id = state.state_id  
    left join contact_info on contact_info.contact_id = contact.contact_id  
     and contact_info.is_default = 1  
     and contact_info.deleted = 0  
    inner join checkbook_config on checkbook_config.return_address_id = contact.contact_id  
    WHERE checkbook_config.checkbook_id = @checkbook_id  
     AND checkbook_config.deleted = 0  
     AND checkbook_config.start_date <= getdate()  
     AND (checkbook_config.end_date > getdate() OR checkbook_config.end_date IS NULL)  
  
  end   
  if @return_fax is null   
   set @return_fax = ''  
  
 -- Bank Address Information  
 select  
  @bank_config_id = bank_config.bank_config_id  
 , @bank_id = bank_config.bank_id  
 , @bank_name = bank_config.name  
 --, @routing_number = bank_config.routing_number --JRR 2015-12-21  
 , @routing_number = ba.routing_number --JRR 2015-12-21  
 , @bank_address1 = bank_config.address1  
 , @bank_address2 = bank_config.address2  
 , @bank_city = bank_config.city  
 , @bank_state = state.state_ud  
 , @bank_zip = bank_config.zip  
 from bank_config  
  inner join dbo.bank_account ba on bank_config.bank_id = ba.bank_id  
  inner join checkbook on checkbook.bank_account_id = ba.bank_account_id  
  inner join state on state.state_id = bank_config.state_id  
 where checkbook.checkbook_id = @checkbook_id  
  and bank_config.deleted = 0  
  and bank_config.start_date <= getdate()  
  and (bank_config.end_date > getdate() or bank_config.end_date IS NULL)  
  
   if @@ROWCOUNT = 0  
 begin  
      -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
      SET @error_message = CONCAT('Fatal Error 1 - An error in get_bank_information has occured with checkbook_id: ', ISNULL(@checkbook_id, 0), ' The data is missing or incomplete.')
	  RAISERROR(@error_message, 16, 1) 
 end  
  
set @redirection_address1 = null  
  
if @claim_redirect_rule_id is not null  
 begin  
  select @redirection_name =   
   case contact_address.recipient_type_id  
    when 1 then contact.company  
    when 2 then contact.first_name + ' ' + contact.last_name  
    when 3 then contact_address.recipient_name  
   end  
  , @redirection_address1 = contact_address.address1  
  , @redirection_address2 = contact_address.address2  
  , @redirection_city = contact_address.city  
  , @redirection_state = state.state_ud  
  , @redirection_zip = contact_address.zip  
  , @redirection_phone = isnull(contact_info.contact_info,'')  
  , @redirection_method = 'COURIER TO WEB-TPA'  
  from contact   
   inner join contact_address  on contact_address.contact_id = contact.contact_id and contact_address.is_default = 1  
   inner join state  on contact_address.state_id = state.state_id  
   left join contact_info  on contact_info.contact_id = contact.contact_id and contact_info.is_default = 1  
   inner JOIN claim_redirect_rule   
    ON contact.contact_id = claim_redirect_rule.contact_id  
   WHERE claim_redirect_rule.claim_redirect_rule_id = @claim_redirect_rule_id  
  
  if @@ROWCOUNT = 0  
  begin  
       -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
       SET @error_message = CONCAT('Fatal Error 2 - An error in get_redirection_address has occured with checkbook_rule_id: ', ISNULL(@checkbook_rule_id, 0), ' checkbook_config_id: ', ISNULL(@checkbook_config_id, 0))
	   RAISERROR(@error_message, 16, 1) 

  end  
     
  select @redirection_reason =   
    'Claim redirect rule requested by a claims manager'   
 end  
else  -- end of mod 12/03/2012  
 if @checkbook_rule_id is not null  
 begin  
  select @redirection_name =   
   case contact_address.recipient_type_id  
    when 1 then contact.company  
    when 2 then contact.first_name + ' ' + contact.last_name  
    when 3 then contact_address.recipient_name  
   end  
  , @redirection_address1 = contact_address.address1  
  , @redirection_address2 = contact_address.address2  
  , @redirection_city = contact_address.city  
  , @redirection_state = state.state_ud  
  , @redirection_zip = contact_address.zip  
  , @redirection_phone = isnull(contact_info.contact_info,'')  
  , @redirection_method = 'COURIER TO WEB-TPA'  
  from contact   
   inner join contact_address  on contact_address.contact_id = contact.contact_id and contact_address.is_default = 1  
   inner join state  on contact_address.state_id = state.state_id  
   left join contact_info  on contact_info.contact_id = contact.contact_id and contact_info.is_default = 1  
   inner join checkbook_rule on contact.contact_id = checkbook_rule.contact_id  
  where checkbook_rule.checkbook_rule_id = @checkbook_rule_id  
  
  if @@ROWCOUNT = 0  
  begin  
       -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
       SET @error_message = CONCAT('Fatal Error 3 - An error in get_redirection_address has occured with checkbook_rule_id: ', ISNULL(@checkbook_rule_id, 0), ' checkbook_config_id: ', ISNULL(@checkbook_config_id, 0))
	   RAISERROR(@error_message, 16, 1) 
  end  
  
  select @redirection_reason =   
   case checkbook_rule.checkbook_rule_type_id  
   when 1 then   
    case checkbook_rule.checkbook_rule_scope_id  
     when 1 then 'Check redirect rule, amount ' + convert(varchar(10),checkbook_rule.amount) + ' ' + checkbook_rule_action.description  
     when 2 then 'Claim redirect rule, amount ' + convert(varchar(10),checkbook_rule.amount) + ' ' + checkbook_rule_action.description  
    end  
   when 2 then 'AP TYPE REDIRECT RULE, amount ' + convert(varchar(10),checkbook_rule.amount) + ' ' + checkbook_rule_action.description  
   when 3 then 'ALL CHECKS REDIRECTED ' + checkbook_rule_action.description  
   end  
  from checkbook_rule  
   inner join checkbook_rule_action on checkbook_rule_action.checkbook_rule_action_id = checkbook_rule.checkbook_rule_action_id  
  where checkbook_rule.checkbook_rule_id = @checkbook_rule_id  
  
  if @@ROWCOUNT = 0  
  begin  
       -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
       SET @error_message = CONCAT('Fatal Error 4 - An error in get_redirection_reason has occured with checkbook_rule_id: ', ISNULL(@checkbook_rule_id, 0), ' checkbook_config_id: ', ISNULL(@checkbook_config_id, 0))
	   RAISERROR(@error_message, 16, 1) 
  end  
 end    
  
 if @redirection_address1  is not null   
  begin -- determine the redirection code to send to redcard  
   set @redirect_code = null  
   select @redirect_code = code from check_run_redirect_address where name_attn = @redirection_name   
   if @redirect_code is null -- no match  
    begin   
         set @redirect_code = '999'  
  
         -- SEND EMAIL NOTIFICATION =============================================================
         SET @error_message = 'An unknown redirect address was processed for voucher_number ' + @voucher_number_char 
         SET @error_message = CONCAT(@error_message, 'An error in get_redirection_address has occured with checkbook_rule_id: ', ISNULL(@checkbook_rule_id, 0), ' checkbook_config_id: ', ISNULL(@checkbook_config_id, 0))
         
         EXEC [dbo].[finance_email_notification] @user_id, @error_message, @ProgramName, @sp_name
         -----------------------------------------------------------------------------------------
    end   
  end   
 ------------------------------------  
 --  Save Account Header used to create virtual eop's and eob's   
 ------------------------------------  
 if @return_status  = 0 and @checkbook_id <>@last_checkbook_id and @doc_type <> 'COR'  
  begin   
    
  set @last_checkbook_id =  @checkbook_id   
  -- we have one check_run_account_header for each voucher   
  
  insert into check_run_account_header (  
   check_run_id  
  , checkbook_id  
  , checkbook_rule_id  
  , claim_redirect_rule_id  -- elva 12/03/2012  
  , checkbook_config_id  
  , checkbook_name  
  , account_number  
  , signatures_required  
  , check_stock  
  , bank_config_id  
  , bank_id  
  , bank_name  
  , routing_number  
  , bank_address1  
  , bank_address2  
  , bank_city  
  , bank_state  
  , bank_zip  
  , contact_address_id  
  , return_name  
  , return_address1  
  , return_address2  
  , return_city  
  , return_state  
  , return_zip  
  , return_phone  
  , redirection_name  
  , redirection_address1  
  , redirection_address2  
  , redirection_city  
  , redirection_state  
  , redirection_zip  
  , redirection_phone  
  , redirection_reason  
  , redirection_method  
  , created_user_id  
  , modified_user_id )  
  values (  
   @check_run_id  
  , @checkbook_id  
  , @checkbook_rule_id  
  , @claim_redirect_rule_id   -- elva 12/03/2012  
  , @checkbook_config_id  
  , @checkbook_name  
  , @account_number  
  , @signatures_required  
  , @check_stock  
  , @bank_config_id  
  , @bank_id  
  , @bank_name  
  , @routing_number  
  , @bank_address1  
  , @bank_address2  
  , @bank_city  
  , @bank_state  
  , @bank_zip  
  , @contact_address_id  
  , @return_name  
  , @return_address1  
  , @return_address2  
  , @return_city  
  , @return_state  
  , @return_zip  
  , @return_phone  
  , @redirection_name  
  , @redirection_address1  
  , @redirection_address2  
  , @redirection_city  
  , @redirection_state  
  , @redirection_zip  
  , @redirection_phone  
  , @redirection_reason  
  , @redirection_method  
  , @modified_user_id  
  , @modified_user_id )  
  
  set @check_run_account_header_id = scope_identity()  
 end  
  
 -----------------------------------------------  
    -- Get Vendor Information  
    -----------------------------------------------  
 if @doc_type = 'COR'  
  begin   
    SELECT   
     @vendor_ud = c.addressee,  
             @vendor_tax_id = v.tax_id,  
       @vendor_name = LEFT(ltrim(rtrim(isnull(c.addressee,''))),80),  
       @vendor_address1 = LEFT(ltrim(rtrim(isnull(c.address_1,''))),80),  
       @vendor_address2 = LEFT(ltrim(rtrim(isnull( c.address_2,''))),80),  
       @vendor_city = LEFT(ltrim(rtrim(isnull(c.city,''))),30),  
       @vendor_state = c.state,  
       @vendor_zip =  LEFT(ltrim(rtrim(isnull(c.zip,''))),5),  
       @vendor_phone = LEFT(ltrim(rtrim(isnull(c.phone,''))),5)  
   FROM  
    correspondence c   
    left outer join vendor v  on c.primary_correspondence_link_id = v.vendor_id  
   WHERE  
    correspondence_id = @correspondence_id  
    AND c.deleted = 0  
  end   
 else   
  begin   
  
   IF @vendor_id IS NOT NULL  
    BEGIN  
     SELECT @vendor_ud = vendor.vendor_ud,  
         @vendor_tax_id = vendor.tax_id,  
         @vendor_name = LEFT(ltrim(rtrim(isnull(vendor.vendor_nm,''))),80),  
         @vendor_address1 = LEFT(ltrim(rtrim(isnull(vendor.address_1,''))),80),  
         @vendor_address2 = LEFT(ltrim(rtrim(isnull(vendor.address_2,''))),80),  
         @vendor_city = LEFT(ltrim(rtrim(isnull(vendor.city,''))),30),  
         @vendor_state = vendor.state,  
         @vendor_zip =  LEFT(ltrim(rtrim(isnull(vendor.zip,''))),5),  
         @vendor_phone = vendor.phone  
      FROM vendor  
      WHERE vendor.vendor_id = @vendor_id  
  
     --SET @vendor_address2 = ltrim(rtrim(@vendor_address2))  
     --IF @vendor_address2 = '' set @vendor_address2 = null  
    END  
  end   
    
	-----------------------------------------------  
    -- Get Check Information  
    -----------------------------------------------  
    IF @checkbook_check_id IS NOT NULL  
     BEGIN  
		SELECT @check_number = checkbook_check.payment_reference,  -- use payment_reference instead of check_number 08/12/2013 elva  
		       @check_date = checkbook_check.check_date,  
		       @check_amount = checkbook_check.amount,  
		       @check_name = LEFT(ltrim(rtrim(checkbook_check.name)),80),  
		       @check_address1 = LEFT(ltrim(rtrim(isnull(checkbook_check.address1,''))),80),  
		       @check_address2 = LEFT(ltrim(rtrim(isnull(checkbook_check.address2,''))),80),  
		       @check_city = LEFT(ltrim(rtrim(checkbook_check.city)),30),  
		       @check_state = checkbook_check.state,  
		       @check_zip = LEFT(ltrim(rtrim(checkbook_check.zip)),5)  
		FROM checkbook_check  
		WHERE checkbook_check.checkbook_check_id = @checkbook_check_id  
		
		IF @voucher_member_id IS NOT NULL  
			SET @check_attached_for_member = 1  
		
		SET @check_address2 = ltrim(rtrim(isnull(@check_address2,'')))  

		-----------------------------------------------  
		-- Update check alt_check_number on Anthem claims PS 11/25/2025
		-----------------------------------------------   
		 DECLARE @anthem_disbursement_id VARCHAR(100)
		 
		 SELECT @anthem_disbursement_id = d.disbursement_id
		 FROM [dbo].[voucher_claim_procedure_map] vcpm 
		      INNER JOIN [dbo].[claim_procedure] cp ON cp.claim_procedure_id = vcpm.claim_procedure_id
		      INNER JOIN [edee].[dbo].[anthem_claim_invoice_detail] d ON d.claim_id = cp.claim_id
		 WHERE vcpm.voucher_id = @voucher_id
		
		IF @anthem_disbursement_id IS NOT NULL AND ISNUMERIC(@anthem_disbursement_id) = 1
		BEGIN
			UPDATE [dbo].[checkbook_check]
			SET alt_check_number = CONVERT(BIGINT, @anthem_disbursement_id)
			WHERE checkbook_check_id = @checkbook_check_id
		END 
     END  
    ELSE  
     BEGIN  
		SET @check_number = 0  
		SET @check_date = getdate()  
		SET @check_amount = 0  
		SET @check_name = null  
		SET @check_address1 = null  
		SET @check_address2 = null  
		SET @check_city = null  
		SET @check_state = null  
		SET @check_zip = null  
     END  
  

 
  
 -----------------------------------------------  
 -- Determine EOB Suppression : Checkbook Level  (never suppress an EOB with a check attached!)  
 -----------------------------------------------  
 SET @suppress_checkbook = 0  
 IF @check_attached_for_member = 0  
 BEGIN  
  --  see if the entire checkbook is suppressed (regardless of member obligations)  
  IF EXISTS (  
   SELECT 1  
   FROM checkbook_config   
   WHERE checkbook_id = @checkbook_id  
      AND checkbook_config.start_date <= getdate()  
      AND (checkbook_config.end_date > getdate() OR checkbook_config.end_date IS NULL)  
      AND checkbook_config.deleted = 0  
      AND print_eob = 0 )  
  BEGIN  
   SET @suppress_checkbook = 1  
  END  
 END  
  
 IF @return_status = 0  
 begin   
  if @doc_type = 'MAN'   
   begin   
    SELECT @manual_ap_entry_id = ap.manual_ap_entry_id  
     FROM voucher_manual_ap_entry_map m  
      INNER JOIN manual_ap_entry ap on m.manual_ap_entry_id = ap.manual_ap_entry_id and m.deleted = 0 and ap.deleted = 0  
      LEFT JOIN manual_ap_entry_detail d on d.manual_ap_entry_id = ap.manual_ap_entry_id and d.deleted = 0  
     WHERE m.voucher_id = @voucher_id  
      AND d.manual_ap_entry_detail_id is null   
  
     IF @manual_ap_entry_id IS NOT NULL  
     BEGIN  
       -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
       SET @error_message = CONCAT('Fatal Error 5 - An error in check_run_master_redcard has occured. There are missing details for manual_ap_entry_id: ', ISNULL(@manual_ap_entry_id, 0))
	   RAISERROR(@error_message, 16, 1) 
     END  
  
  
    insert into #claiminfo (claim_id, member_id ,subscriber_id, group_contract_id, subscriber_last_name, subscriber_first_name ,  
    member_last_name, member_first_name, correspondence_id , manual_ap_entry_id )   
    SELECT DISTINCT  
      null,    
      null ,  
      null ,  
      null ,  
      manual_ap_entry.group_contract_id,  
      null ,  
      null ,  
      null ,  
      null ,    
      voucher_manual_ap_entry_map.manual_ap_entry_id  -- the primary key for the manual_ap_entries  
         
    FROM voucher  
    INNER JOIN voucher_manual_ap_entry_map  
     ON voucher_manual_ap_entry_map.voucher_id  = voucher.voucher_id   
     AND voucher_manual_ap_entry_map.deleted = 0  
    JOIN manual_ap_entry  
     ON voucher_manual_ap_entry_map.manual_ap_entry_id  = manual_ap_entry.manual_ap_entry_id   
    INNER JOIN manual_ap_entry_detail ON manual_ap_entry_detail.manual_ap_entry_id = manual_ap_entry.manual_ap_entry_id  
     AND manual_ap_entry_detail.deleted = 0  
    WHERE voucher.voucher_id = @voucher_id  
  
    if @vendor_id is not null  
     begin   
      -- set addressee information    
       SET @addressee_name = @vendor_name  
       SET @addressee_address1 = @vendor_address1  
       SET @addressee_address2 = ltrim(rtrim(isnull(@vendor_address2,'')))  
       --IF @addressee_address2 = '' set @addressee_address2 = null  
       SET @addressee_city = left(rtrim(@vendor_city),30)  
       SET @addressee_state = @vendor_state  
       SET @addressee_zip = left(@vendor_zip,5)  
       SET @addressee_phone = @vendor_phone  
     end  
    else  
     begin   
      select @addressee_name =ISNULL(member.first_name,'') + ' ' + member.last_name,  
       @addressee_address1 =  ltrim(isnull(member.address1,'')),   
       @addressee_address2 = ltrim(rtrim(isnull(member.address2,''))),  
       @addressee_city = LEFT(ltrim(rtrim(ISNULL(member.city,''))),30),  
       @addressee_state = ISNULL(member.state,''),  
       @addressee_zip = LEFT(ltrim(rtrim(ISNULL(member.zipcode,''))),5),  
        @member_alt_last_name = isnull(member.alt_last_name,''),  
       @member_alt_first_name = isnull(member.alt_first_name,'')  
      FROM member  
        WHERE member.member_id = @voucher_member_id  
  
      if len(@addressee_address1) = 0  
       or len(@addressee_city) = 0    
       or len(@addressee_state) = 0  
       or len( @addressee_zip) = 0   
       begin   
        select @addressee_name =ISNULL(member.first_name,'') + ' ' + member.last_name,  
         @addressee_address1 = ltrim(isnull(member.address1,'')),  
         @addressee_address2 = ltrim(rtrim(isnull(member.address2,''))),  
         @addressee_city =  LEFT(ltrim(rtrim(ISNULL(member.city,''))),30),  
         @addressee_state = ISNULL(member.state,''),  
         @addressee_zip = LEFT(ltrim(rtrim(ISNULL(member.zipcode,''))),5),  
          @member_alt_last_name = isnull(member.alt_last_name,''),  
         @member_alt_first_name = isnull(member.alt_first_name,'')  
        FROM member  
        WHERE member.member_id = @subscriber_member_id  
       end   
  
       if LEN(@member_alt_last_name) > 0  
       BEGIN  
        SET @addressee_last_name = @member_alt_last_name  
        SET @addressee_first_name = @member_alt_first_name  
        SET @addressee_name = LEFT(rtrim (ISNULL(@member_alt_first_name,'') + ' ' + @member_alt_last_name),80)  
       END  
     END   
  
     -- elva added 04/18/2017  
    select @addressee_attn = left(rtrim(isnull(attention_line,'')),45) FROM voucher  -- put null inside elva 05/07/2019  
    INNER JOIN voucher_manual_ap_entry_map  
     ON voucher_manual_ap_entry_map.voucher_id  = voucher.voucher_id   
     AND voucher_manual_ap_entry_map.deleted = 0  
    JOIN manual_ap_entry  
     ON voucher_manual_ap_entry_map.manual_ap_entry_id  = manual_ap_entry.manual_ap_entry_id   
    WHERE voucher.voucher_id = @voucher_id   
  
    set @created_master_record = 0   
   
   end -- if MAN  
  
  if @doc_type = 'EOB'   
      
  
   -----------------------------------------------  
   -- Get All Claims For Voucher for EOB the sort is different   
   -----------------------------------------------  
   begin   
         
  
    insert into #claiminfo (claim_id, member_id , subscriber_id,group_contract_id, subscriber_last_name, subscriber_first_name ,  
    member_last_name, member_first_name)   
    SELECT DISTINCT  
      claim.claim_id,  
      eligibility.member_id,  
      eligibility.subscriber_id,  
      eligibility.group_contract_id,  
      subscriber.last_name,  
      subscriber.first_name,  
      member.last_name,  
      member.first_name  
      --claim_procedure_status.show_on_eob    
     FROM voucher  
     JOIN voucher_claim_procedure_map  
      ON voucher_claim_procedure_map.voucher_id = voucher.voucher_id  
       AND voucher_claim_procedure_map.deleted = 0  
     JOIN claim_procedure  
      ON claim_procedure.claim_procedure_id = voucher_claim_procedure_map.claim_procedure_id  
     JOIN claim_procedure_status  
      ON claim_procedure_status.claim_procedure_status_id = claim_procedure.claim_procedure_status_id   
      AND claim_procedure_status.show_on_eob = 1  
     JOIN claim  
      ON claim.claim_id = claim_procedure.claim_id  
     JOIN eligibility  
      ON eligibility.eligibility_id = claim.eligibility_id  
     JOIN member   
      ON eligibility.member_id = member.member_id  
     JOIN member subscriber  
      ON eligibility.subscriber_id = subscriber.member_id  
     WHERE voucher.voucher_id = @voucher_id  
    ORDER BY eligibility.member_id,  
      eligibility.subscriber_id -- do not change this sort order.  it is needed for logic below  
  end -- if eob  
  
  if @doc_type = 'EOP'   
  
  -----------------------------------------------  
   -- Get All Claims For Voucher for EOP the sort is different   
   -----------------------------------------------  
    
   BEGIN  
   -----------------------------------------------  
    -- Determine EOB Suppression : EOP Level  (never suppress an EOP with a check attached!)  
    -- Do not change the order of the suppression statements.  
    -----------------------------------------------  
    SET @suppress_eop = 0  
  
    -----------------------------------------------  
    -- Decide which claims to suppress  
    -----------------------------------------------  
  
    INSERT INTO @suppress_claims ( claim_id, suppress )  
    SELECT DISTINCT c.claim_id, 0  
    FROM [dbo].[voucher] v
         INNER JOIN [dbo].[voucher_claim_procedure_map] vcpm ON vcpm.voucher_id = v.voucher_id  
         INNER JOIN [dbo].[claim_procedure] cp ON cp.claim_procedure_id = vcpm.claim_procedure_id  
         INNER JOIN [dbo].[claim_procedure_status] cps ON cps.claim_procedure_status_id = cp.claim_procedure_status_id        
         INNER JOIN [dbo].[claim] c ON c.claim_id = cp.claim_id 
		 INNER JOIN [dbo].[eligibility] e ON e.eligibility_id = c.eligibility_id
		 LEFT JOIN [dbo].[claim_file_source_map] cfsm ON cfsm.claim_id = c.claim_id
    WHERE 
		v.voucher_id = @voucher_id 
		AND vcpm.deleted = 0
	    AND @check_run_community_id NOT IN (50, 55, 57, 58, 62, 64, 65)
		AND (    (cps.show_on_eop = 1 OR cps.show_on_835 = 1) 
		      OR (ISNULL(cfsm.added_by, '') = 'claim_negate')  -- 06/24/2026 46972 Send negates for Medica groups (M00004-M00007)
		      OR (cps.claim_procedure_status_id IN (61, 127))  -- 07/08/2026 46972 Send FADJ Refund/Net Refund for Medica groups (M00004-M00007)
			 ) 

	-- 10/30/2019 added check_run_community_id <> 50 - if it is nextera every claim is suppressed   --11/03/2022 SN adding 57,58
    -- 08/19/2021 added bcbs funding community 55  
    -- 10/30/2019 added following condition.  If it is check run community 50 and it is a no_pay provider it is treated as any other instance   
    -- 08/19/2021 added check run community 55 BCBS funding community  
	-- 12/31/2024 added check run community 62 Florida Blue OOS 
	-- 01/12/2026 #44757 added check run community Anthem JAA (64) and medica UHC (65)
    INSERT INTO @suppress_claims ( claim_id, suppress )  
    SELECT DISTINCT c.claim_id, 0  
    FROM [dbo].[voucher] v
         INNER JOIN [dbo].[voucher_claim_procedure_map] vcpm ON vcpm.voucher_id = v.voucher_id  
         INNER JOIN [dbo].[claim_procedure] cp ON cp.claim_procedure_id = vcpm.claim_procedure_id  
         INNER JOIN [dbo].[claim_procedure_status] cps ON cps.claim_procedure_status_id = cp.claim_procedure_status_id        
         INNER JOIN [dbo].[claim] c ON c.claim_id = cp.claim_id 
		 INNER JOIN [dbo].[eligibility] e ON e.eligibility_id = c.eligibility_id
		 LEFT JOIN [dbo].[claim_file_source_map] cfsm ON cfsm.claim_id = c.claim_id
    WHERE 
		v.voucher_id = @voucher_id 
	    AND vcpm.deleted = 0
	    AND @check_run_community_id IN (50, 55, 57, 58, 62, 64, 65) AND @no_pay = 1 AND @checkbook_id <> 1575 --11/03/2022 Added 57,58; --01/12/2026 #44757 added 64,65
		AND (    (cps.show_on_eop = 1 OR cps.show_on_835 = 1) 
		      OR (ISNULL(cfsm.added_by, '') = 'claim_negate')  -- 06/24/2026 46972 Send negates for Medica groups (M00004-M00007)
		      OR (cps.claim_procedure_status_id IN (61, 127))  -- 07/08/2026 46972 Send FADJ Refund/Net Refund for Medica groups (M00004-M00007)
			 ) 

	-- elva 01/26/2024 added logic for checkbook 1575 Baptist Pensecola.  Basically the suppress_claims all starts out with them set = 0 (dont suppress)
	-- this is then used to drive the suppression  If they are not in the table all they will be suppressed because the default is to suppress
  
    -- TODO: Decide which claims we're suppressing  
    --UPDATE @suppress_claims SET  
    -- suppress = 1  
    --WHERE claim_id in ( list to suppress )  
  -- sn modified 05/22/2023 prudential has requested eop suppresseion based on eob code of (3292)
  --select @checkbook_id
  -- elva modified 06/02/2023 to remove this.  Sometimes there is only one claim so we can't suppress the eop
   --		IF ( @checkbook_id = 1427)        
   -- 		Begin
			--	select 
			--		distinct sc.claim_id, cpe.eob_id  into #tempsuppress
			--		from @suppress_claims sc inner join claim_procedure  cp on sc.claim_id = cp.claim_id
   --      			INNER JOIN claim_procedure_eob cpe  ON cp.claim_procedure_id = cpe.claim_procedure_id  
   --      			where cpe.eob_id in (3292)
			--		update @suppress_claims
			--			set suppress = 1
			--		from @suppress_claims sp inner join #tempsuppress ts on sp.claim_id = ts.claim_id
			--		drop table #tempsuppress
			--end 
    -----------------------------------------------  
    -- Suppress EOP if all claims are suppressed  
    -----------------------------------------------  
    IF NOT EXISTS (  
     SELECT 1  
     FROM @suppress_claims  
     WHERE suppress = 0  
     )  
    BEGIN  
     SET @suppress_eop = 1  
    END  
  
    -- added 10/30/2019 , added bcbs commuity 55 08/19/2021  
	-- #44757 added 01/12/2026, added community 64, 65
    if @checkbook_check_id is not null and @check_run_community_id in (50, 55, 57, 58, 62, 64, 65)  AND NOT EXISTS (  --11/03/2022 SN added 57,58
     SELECT 1  
     FROM @suppress_claims  
     WHERE suppress = 0  
     )  
    BEGIN  
     SET @suppress_eop = 1  
    END  
    -----------------------------------------------  
    -- Are there any reasons not to suppress the EOP?  
    -----------------------------------------------  
	-- #44757 added 01/12/2026, added community 64, 65
    IF @checkbook_check_id IS NOT NULL and @check_run_community_id not in (50, 55, 57, 58, 62, 64, 65) -- added 10/30/2019 and @check_run_community_id <> 50, 08/19/2021 added 55   --11/03/2022 SN added 57,58
    BEGIN  
     --  Never suppress an EOP with a check!  
     SET @suppress_eop = 0  
    END  
  
      
         
    -----------------------------------------------  
    -- If we suppress all the claims but not the EOP generate an error  
    -----------------------------------------------  
    IF @suppress_eop = 0 AND  
     NOT EXISTS (  
      SELECT 1  
      FROM @suppress_claims  
      WHERE suppress = 0  
     )  
    BEGIN  
       -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
       SET @error_message = CONCAT('Fatal Error 6 - An error in check_run_master_redcard has occured with voucher_id ', ISNULL(@voucher_id, 0),  ' by trying to suppress all claims for an EOP with a check attached.')
	   RAISERROR(@error_message, 16, 1) 
    END  
  
  
    insert into #claiminfo (claim_id, member_id , subscriber_id ,group_contract_id, subscriber_last_name, subscriber_first_name ,  
     member_last_name, member_first_name)   
     SELECT DISTINCT  
        c.claim_id,  
        e.member_id,  
        e.subscriber_id,  
        e.group_contract_id,  
        s.last_name,  
        s.first_name,  
        m.last_name,  
        m.first_name   
     FROM 
		[dbo].[voucher] v
        INNER JOIN [dbo].[voucher_claim_procedure_map] vcpm ON vcpm.voucher_id = v.voucher_id    
        INNER JOIN [dbo].[claim_procedure] cp ON cp.claim_procedure_id = vcpm.claim_procedure_id  
        INNER JOIN [dbo].[claim_procedure_status] cps ON cps.claim_procedure_status_id = cp.claim_procedure_status_id   
        INNER JOIN [dbo].[claim] c ON c.claim_id = cp.claim_id  
        INNER JOIN [dbo].[eligibility] e ON e.eligibility_id = c.eligibility_id  
        INNER JOIN [dbo].[member] m ON e.member_id = m.member_id  
        INNER JOIN [dbo].[member] s ON e.subscriber_id = s.member_id
	    LEFT JOIN [dbo].[claim_file_source_map] cfsm ON cfsm.claim_id = c.claim_id
     WHERE 
		v.voucher_id = @voucher_id  
	    AND vcpm.deleted = 0
		AND (    (cps.show_on_eop = 1 OR cps.show_on_835 = 1) 
		      OR (ISNULL(cfsm.added_by, '') = 'claim_negate')  -- 06/24/2026 46972 Send negates for Medica groups (M00004-M00007)
		      OR (cps.claim_procedure_status_id IN (61, 127))  -- 07/08/2026 46972 Send FADJ Refund/Net Refund for Medica groups (M00004-M00007)
			 ) 

      --the eop has a different sort order.    
     ORDER BY  -- added 3/23/2006 by jt so large EOPs with many claims would sort by member.  requested by clients.  
        s.last_name  
       ,s.first_name  
       ,m.last_name  
       ,m.first_name  
   end -- end EOP  
  

  if @doc_type = 'COR' -- correspondence record   
   begin   
    insert into #claiminfo (claim_id, member_id , subscriber_id ,group_contract_id, subscriber_last_name, subscriber_first_name ,  
     member_last_name, member_first_name, correspondence_id)   
    SELECT null,  
      eligibility.member_id,  
      eligibility.subscriber_id,  
      eligibility.group_contract_id,  
      subscriber.last_name,  
      subscriber.first_name,  
      member.last_name,  
      member.first_name,  
      c.correspondence_id  
    FROM  
     correspondence c   
     INNER JOIN correspondence_eligibility_link cml  ON c.correspondence_id = cml.correspondence_id  
     INNER JOIN eligibility   ON cml.eligibility_id = eligibility.eligibility_id  
     --INNER JOIN employergroup  (NOLOCK) ON eligibility.employergroup_id = employergroup.employergroup_id  
     --INNER JOIN benefitplan bp (NOLOCK) ON eligibility.benefitplan_id = bp.benefitplan_id  
     INNER JOIN member   ON member.member_id = eligibility.member_id  
     INNER JOIN member subscriber  ON subscriber.member_id = eligibility.subscriber_id  
    WHERE  
     c.correspondence_id = @correspondence_id  
     AND c.deleted = 0  
     AND cml.deleted = 0  

	 --	jjt	07.25.2024		Without this criteria we're duplicating detail lines in free form letters.
	 and c.correspondence_type_id not in (
			11		-- W9
		,	83		-- W9 Penalty  
		,	114		-- B NOTICE ONE
		,	115		-- B NOTICE TWO  
		)
    ORDER BY  
     cml.correspondence_eligibility_link_id  

	 -- elva 06/11/2024 get any of the type c.correspondence_type_id in (11,83,114,115)	--	W9, B Notice One, B Notice Two
	-- they are not tied to a member , a claim or an employergroup
    insert into #claiminfo (claim_id, member_id , subscriber_id ,group_contract_id, subscriber_last_name, subscriber_first_name ,  
     member_last_name, member_first_name, correspondence_id)   
    SELECT null,  
      null,  
      null,  
      null,  
      null,  
      null,  
      null,  
      null,  
      c.correspondence_id  
    FROM  
     correspondence c   
     INNER JOIN correspondence_vendor_link cml  ON c.correspondence_id = cml.correspondence_id  
    WHERE  
     c.correspondence_id = @correspondence_id  
     AND c.deleted = 0  
     AND cml.deleted = 0  

	 --	jjt	07.25.2024		Without this criteria we're duplicating detail lines in free form letters.
	 and c.correspondence_type_id in (
			11		-- W9
		,	83		-- W9 Penalty  
		,	114		-- B NOTICE ONE
		,	115		-- B NOTICE TWO  
		)
    ORDER BY  
     cml.correspondence_vendor_link_id  
	-- elva end of add 

    set @created_master_record = 0   
  
   end -- doc_type = 'cor'  
  end -- return status = 0   
  
  -- 06/12/2024 elva debug

 -- end of selecting data now start processing it  
 -- how many total records do we need to process  
 select @record_count = count(*) from #claiminfo  
 select @record_id = min(#claiminfo.claiminfo_id) from #claiminfo   
  
 set @created_master_record = 0   
 set @check_run_eob_header_id = null  
 set @check_run_eop_header_id = null  
 set @claim_sequence = 0  -- the claimnondetail record has a sequence which starts at 0 and is incriminted by one for each claim   
 set @servicelinesequence = 0   
 set @first_time = 1  

 -----------------------------------------------  
 -- Determine @NSA_flag  
 -----------------------------------------------  
IF EXISTS (SELECT 1 
             FROM #claiminfo ci 
			INNER JOIN [dbo].[claim] c ON c.claim_id = ci.claim_id
            INNER JOIN [dbo].[claim_procedure] cp ON cp.claim_id = c.claim_id          
	        WHERE ci.claim_id IS NOT NULL
			  and exists (select 1 
				            from [dbo].[claim_procedure_eob] e 
				    	   where e.claim_procedure_id = cp.claim_procedure_id 
						    AND (
                    e.eob_id IN (3842, 3849, 3873, 3940, 3867, 3869, 12447) -- Added  EOB ID 12447 for US#45558
                    OR (
                        e.eob_id IN (12108, 12119) -- US#44604
                        AND EXISTS (
                            SELECT 1
                            FROM dbo.claim_file_source_map cfsm
                            WHERE cfsm.claim_id = c.claim_id
                              AND cfsm.claim_file_source_id IN (15, 16)
                        )
                    )
                  )
      )
)
    SET @NSA_flag = 1;
ELSE
    SET @NSA_flag = 0;

 --------------------------------------------
 -- Determine External Edit Codes @EEC_flag
 --------------------------------------------
 IF EXISTS (SELECT 1 FROM #claiminfo ci 
				INNER JOIN [dbo].[claim] c ON c.claim_id = ci.claim_id
                INNER JOIN [dbo].[claim_procedure] cp ON cp.claim_id = c.claim_id 
		        INNER JOIN [dbo].[claim_procedure_external_edit] ee ON cp.claim_procedure_id = ee.claim_procedure_id  
		    WHERE 
				ee.edit_code IN ('PRQPA','PRSBG','PRCNK') 
				AND cp.claim_procedure_id IS NOT NULL 
				AND ci.claim_id IS NOT NULL)	
	SET @EEC_flag = 1
 ELSE
	SET @EEC_flag = 0

 ----------------------------------------------------------
 -- Add External Edit Codes for UB claims
 ----------------------------------------------------------
  IF EXISTS (SELECT 1 FROM #claiminfo ci 
				INNER JOIN [dbo].[claim] c ON c.claim_id = ci.claim_id
                INNER JOIN [dbo].[claim_procedure] cp ON cp.claim_id = c.claim_id 
		        INNER JOIN [dbo].[claim_ub92_service] cus ON cp.claim_procedure_id = cus.claim_procedure_id
				INNER JOIN [dbo].[claim_ub92_service_external_edit] cusee ON cus.claim_ub92_service_id = cusee.claim_ub92_service_id
		    WHERE 
				cusee.edit_code in ('PRQPA','PRSBG','PRCNK')
				AND cusee.[override] = 0
				AND cp.claim_procedure_id IS NOT NULL 
				AND ci.claim_id IS NOT NULL)	
	SET @EEC_ub_flag = 1
 ELSE
	SET @EEC_ub_flag = 0



 ----------------------------------------------------------
 -- Set QPA/IDR Language Trigger Information
 ----------------------------------------------------------
 IF ((@doc_type = 'EOP' OR @doc_type = 'EOB') AND (@NSA_flag = 1 OR @EEC_flag = 1 OR @EEC_ub_flag = 1))	-- Joe 05/06/2025
 BEGIN  
	IF @doc_type = 'EOP'  
		SET @QPA_IDR_Trigger = 'DIS'   
	ELSE   
		SET @QPA_IDR_Trigger = 'NSA'  
 END  


-- through here begin and ends are good  
 while @record_id <= @record_count   
 begin   
  if @doc_type in ('EOB', 'EOP')  
   begin   
    select  @claim_id = claim_id,  @claim_member_id = member_id,  @claim_subscriber_member_id = subscriber_id from #claiminfo   
     where claiminfo_id = @record_id   
  
  	-- mjp 06/07/2024 start 
		truncate table #temp_member_eligibility
		insert into #temp_member_eligibility(eligibility_id)
		select eligibility_id
		  from eligibility e
		 where e.member_id = @claim_member_id
	-- mjp 06/07/2024 end 
    -------------------------------------------------  
    ---- Get Claim Information  
    -------------------------------------------------  
    SELECT   
     @claim_ud = ltrim(rtrim(claim.claim_ud)) + '-R' + CONVERT(varchar(10),claim.revision_number),  
     -- commented out the case statement we want the revision number all the time even if it is 0  elva11/15/2013  
      --CASE ISNULL(claim.revision_number,0)  
      --WHEN 0 THEN claim.claim_ud  
      --ELSE claim.claim_ud + '-R' + CONVERT(varchar(10),claim.revision_number) END,  
     @revision_number = claim.revision_number,  
     @claim_type_id = claim.claim_type_id ,   -- elva 11/27/2018  
     @member_privacy_type_id = member.member_privacy_type_id,  
     @guardian_name = LEFT(ltrim(rtrim(ISNULL(member.alt_first_name,'') + ' ' + ISNULL(member.alt_last_name,''))),50),  
     @member_alt_last_name = member.alt_last_name,  
     @member_alt_first_name = member.alt_first_name,  
     @member_name = LEFT(LTRIM(rtrim(ISNULL(member.first_name,'') + ' ' + member.last_name)),80),  
     @member_last_name = LTRIM(rtrim(isnull(member.last_name,''))),  
     @member_first_name = member.first_name,  
     @member_ssn = ISNULL(member.ssn,''),  
     @member_address1 = LEFT(ltrim(rtrim(ISNULL(member.address1,''))),80),  
     @member_address2 = ltrim(rtrim(ISNULL(member.address2,''))),  
     @member_city = LEFT(ltrim(rtrim(ISNULL(member.city,''))),30),  
     @member_state = ISNULL(member.state,''),  
     @member_zip = LEFT(ltrim(rtrim(ISNULL(member.zipcode,''))),5),  
     @member_phone = member.phone,  
     @member_eligibility_ud = eligibility.eligibility_ud,  
     @employergroup_id = group_contract.employergroup_id,  
     @group_contract_id = group_contract.group_contract_id,  
     @benefitplan_id = group_contract.benefitplan_id,  
     @ERISA = ISNULL(employergroup.erisa_group,1),  
     @print_accumulators_on_eob = employergroup.print_accumulators_on_eob,  
     @subscriber_group = ISNULL(employergroup.employergroup_ud,''),  
     @subscriber_group_name = ISNULL(employergroup.employergroup_nm,''),  
     @subscriber_plan =  ISNULL(benefitplan.benefitplan_ud,''),  
     @subscriber_name = LEFT(LTRIM(rtrim(ISNULL(subscriber.first_name,'') + ' ' + subscriber.last_name)),80),  
     @subscriber_last_name = subscriber.last_name,  
     @subscriber_first_name = subscriber.first_name,  
     @subscriber_ssn = ISNULL(subscriber.ssn,''),  
     @subscriber_address1 = LEFT(rtrim(ltrim(ISNULL(subscriber.address1,''))),80),  
     @subscriber_address2 = LEFT(ltrim(rtrim(ISNULL(subscriber.address2,''))),80),  
     @subscriber_city = LEFT(ltrim(rtrim(ISNULL(subscriber.city,''))),30),  
     @subscriber_state = ISNULL(subscriber.state,''),  
     @subscriber_zip = LEFT(ltrim(rtrim(ISNULL(subscriber.zipcode,''))),5),  
     @subscriber_phone = ISNULL(subscriber.phone,''),  
     @vendor_id = vendor.vendor_id,  
     @vendor_ud = vendor.vendor_ud,  
     @vendor_name = ltrim(rtrim(vendor.vendor_nm)),  
     @vendor_tax_id = left(ltrim(rtrim(vendor.tax_id)),11),  
     @vendor_address1 = ltrim(rtrim(vendor.address_1)),  
     @vendor_address2 = ltrim(rtrim(ISNULL(vendor.address_2,''))),  
     @vendor_city = ltrim(rtrim(ISNULL(vendor.city,''))),  
     @vendor_state = vendor.state,  
     @vendor_zip = ltrim(rtrim(ISNULL(vendor.zip,''))),  
     @vendor_phone = ISNULL(vendor.phone,''),  
     @policy_origination_state = isnull(state_ud,'')  
    FROM claim   
     LEFT JOIN provider_id_map  ON provider_id_map.provider_id_map_id = claim.provider_id_map_id  
     LEFT JOIN provider  ON provider.provider_id = provider_id_map.provider_id  
     INNER JOIN eligibility  ON eligibility.eligibility_id = claim.eligibility_id  
     INNER JOIN member  ON member.member_id = eligibility.member_id  
     INNER JOIN member  AS subscriber ON subscriber.member_id = eligibility.subscriber_id  
     INNER JOIN vendor ON vendor.vendor_id = claim.vendor_id  
     INNER JOIN group_contract  ON group_contract.group_contract_id = eligibility.group_contract_id  
     INNER JOIN benefitplan  ON benefitplan.benefitplan_id = group_contract.benefitplan_id  
     INNER JOIN employergroup ON group_contract.employergroup_id = employergroup.employergroup_id  
     left outer join state on group_contract.policy_origination_state_id = state.state_id   
    WHERE claim.claim_id = @claim_id  
  
    select distinct @claim_type = bt.name from claim c   
    inner join claim_procedure cp  on c.claim_id = cp.claim_id  
    left join claim_procedure_benefit cpb on cp.claim_procedure_id = cpb.claim_procedure_id  
    left join benefit b on cpb.benefit_id = b.benefit_id  
    left join product p  on b.product_id = p.product_id  
    left join benefit_type_grouping bt on p.benefit_type_grouping_id = bt.benefit_type_grouping_id   
    where bt.name is not null and c.claim_id = @claim_id   
   end   

    -----------------------------------------------  
    -- Get the carrier name (Underwriting Company Name) PS 11/08/2024
    -----------------------------------------------   
    SELECT TOP 1 @carrier_name = ISNULL(d.report_field_10,'')  
    FROM  
		group_contract_external_vendor_report_map m   
		INNER JOIN external_vendor_report_data d  ON m.external_vendor_report_data_id = d.external_vendor_report_data_id  
    WHERE  
		m.group_contract_id = @group_contract_id  
		AND m.deleted = 0  
		AND d.deleted = 0  
    ORDER BY m.group_contract_external_vendor_report_map_id  

 


  if @doc_type = 'EOB'   
   begin   
    -------------------------------------------------------------------------------------  
    --  
    -- EOB SUPPRESSION RULES  
    --   
    -- In general we'll suppress an EOB if there is not a check attached and there are  
    -- no member obligations such as copay or deductible.  
    --  
    -- This general guidline will be overridden by the settings in the check_run_eob_suppression_config  
    -- table.  If we find the checkbook_id or employergroup_id in the config table we'll override our  
    -- default processing.    
    --  
    -------------------------------------------------------------------------------------  


  set @force_to_print = 0  
        
    ---- Look for checkbook level suppression override  
    if exists (   
     select 1   
     from check_run_eob_suppression_config   
     where must_print = 1  
      and checkbook_id = @checkbook_id  
      and (   
       employergroup_id is null    -- entire checkbook must print  
       or employergroup_id = @employergroup_id -- this group on the checkbook must print  
       )  
      and deleted = 0 )  
     begin  
      -- This EOB must print  
      set @force_to_print = 1  
     end  
       
    -- Look for employer group level suppression override  
    if exists (   
     select 1   
     from check_run_eob_suppression_config   
     where must_print = 1  
      and checkbook_id is null  
      and employergroup_id = @employergroup_id  
      and deleted = 0 )  
     begin  
      -- This EOB must print  
      set @force_to_print = 1  
     end  
  
  
    set @suppress_member_obligation = 0  
  
    -- Look for checkbook level suppression override  
    if exists (   
     select 1   
     from check_run_eob_suppression_config   
     where suppress_member_obligation = 1  
      and checkbook_id = @checkbook_id  
      and (   
       employergroup_id is null    -- entire checkbook  
       or employergroup_id = @employergroup_id -- this group on the checkbook  
       )  
      and deleted = 0 )  
     begin  
      -- Member obligation can be suppressed.  
      set @suppress_member_obligation = 1  
     end  
       
    ---- Look for employer group level suppression override  
    if exists (   
     select 1   
     from check_run_eob_suppression_config   
     where suppress_member_obligation = 1  
      and checkbook_id is null  
      and employergroup_id = @employergroup_id  
      and deleted = 0 )  
     begin  
      -- Member obligation can be suppressed.  
      set @suppress_member_obligation = 1  
     end  
      
	    -----------------------------------------------  
    -- Determine whether to include copay as member obligation  
    -- 03/18/2018 jjt Added copay logic here.  
    -----------------------------------------------  
    set @include_copay_in_member_obligation = 0  
  
    -- Look for checkbook level copay override  
    if exists (   
     select 1   
     from check_run_eob_suppression_config   
     where include_copay_in_member_obligation = 1  
      and checkbook_id = @checkbook_id  
      and (   
       employergroup_id is null    -- entire checkbook includes copay  
       or employergroup_id = @employergroup_id -- this group on the checkbook includes copay  
       )  
      and deleted = 0 )  
    begin  
     set @include_copay_in_member_obligation = 1  
    end  
       
    -- Look for employer group level copay override  
    if exists (   
     select 1   
     from check_run_eob_suppression_config   
     where include_copay_in_member_obligation = 1  
      and checkbook_id is null  
      and employergroup_id = @employergroup_id  
      and deleted = 0 )  
    begin  
     set @include_copay_in_member_obligation = 1  
    end  
    -------------------------------------------------  
    ---- Determine EOB Suppression : EOB Level  (never suppress an EOB with a check attached!)  
    -------------------------------------------------  
    SET @suppress_eob = 0  -- assume we have to print the EOB, then look to see if we can suppress it  
  -- try and end it here    
    
    IF @force_to_print = 0  -- we can try to suppress  
  
     BEGIN  
     
      -- Do not change the order of these three outermost if statements below without studying hard.  
      
      -- no check attached an the checkbook has "print_eob" turned off  

	  -- sn modified 05/22/2023 prudential has requested eob suppresseion based on eob code of (3292,3906))
	 --select @checkbook_id
   		IF ( @checkbook_id = 1427)        
    		Begin
			if exists (select top 1
					claim_id, cp.claim_procedure_id, cpe.eob_id  from  claim_procedure  cp
         			INNER JOIN claim_procedure_eob cpe  ON cp.claim_procedure_id = cpe.claim_procedure_id  
         			where cp.claim_id = @claim_id and cpe.eob_id in (3292,3906))
					SET @suppress_eob = 1 	
			end 
     
     IF @check_attached_for_member = 0 AND @suppress_checkbook = 1  
      SET @suppress_eob = 1  
  
   --   -- no check attached but the checkbook has "print_eob" turned on so can only suppress without member obligation  
      IF @check_attached_for_member = 0 AND @suppress_eob = 0  
      BEGIN  
   --    -- are we allowed to suppress member obligation?  
       IF @suppress_member_obligation = 1  
        BEGIN  
         SET @suppress_eob = 1  
        END  
       -- look for member obligations...we can't suppress with member obligations  
       ELSE IF EXISTS (  
       	-- mjp 06/07/2024 start 
        SELECT 1  
        FROM #temp_member_eligibility e   
         INNER JOIN claim  ON e.eligibility_id = claim.eligibility_id  
         INNER JOIN claim_procedure  ON claim.claim_id = claim_procedure.claim_id  
         LEFT JOIN claim_procedure_benefit ON claim_procedure.claim_procedure_id = claim_procedure_benefit.claim_procedure_id AND claim_procedure_benefit.deleted = 0  
         INNER JOIN voucher_claim_procedure_map  ON voucher_claim_procedure_map.claim_procedure_id = claim_procedure.claim_procedure_id AND voucher_claim_procedure_map.deleted = 0  
        WHERE  
         voucher_claim_procedure_map.voucher_id = @voucher_id  
        GROUP BY claim_procedure.claim_id  
        HAVING   
         SUM (COALESCE(claim_procedure_benefit.deductible,0.00)) > 0  
         OR SUM (COALESCE(claim_procedure_benefit.coinsurance_amount,0.00)) > 0  
         OR SUM (COALESCE(claim_procedure_benefit.ineligible_amount,0.00)) > 0  
         OR SUM (COALESCE(claim_procedure.ineligible_amount,0.00)) > 0   
         --SUM (COALESCE(claim_procedure_benefit.copay_amount,0.00)) > 0  
         -- jjt 03/15/2018 Some groups or checkbooks may want to count copay as member obligation  
         or (  
          @include_copay_in_member_obligation = 1   
          and sum (coalesce(claim_procedure_benefit.copay_amount,0.00)) > 0  
          )  
         )  
		-- mjp 06/07/2024 end 

        BEGIN  
         -- if we find member obligations on any claim on the EOB don't suppress it  
         SET @suppress_eob = 0  
        END  
       ELSE  
        BEGIN  
         -- no member obligations found on EOB  
         SET @suppress_eob = 1  
        END  
  
   --    --  suppress all 003s when all lines are denied status type (dupe claims)  
       IF @suppress_eob = 0  
       BEGIN  
        IF EXISTS (  
         --  at least one dupe procedure line on EOB  
         SELECT 1  
          FROM #temp_member_eligibility elig   
          INNER JOIN claim  ON elig.eligibility_id = claim.eligibility_id  
          INNER JOIN claim_procedure  ON claim.claim_id = claim_procedure.claim_id  
          INNER JOIN claim_procedure_eob e  ON claim_procedure.claim_procedure_id = e.claim_procedure_id  
         -- INNER JOIN claim_procedure_benefit ON claim_procedure.claim_procedure_id = claim_procedure_benefit.claim_procedure_id AND claim_procedure_benefit.deleted = 0  
          INNER JOIN voucher_claim_procedure_map ON voucher_claim_procedure_map.claim_procedure_id = claim_procedure.claim_procedure_id AND voucher_claim_procedure_map.deleted = 0  
         WHERE  
          voucher_claim_procedure_map.voucher_id = @voucher_id  
          AND e.eob_id IN ( 3,524,581,815,1584 ) -- EOB 003x  
         )  
        AND NOT EXISTS (  
         --  any claim procedures not denied on EOB  
         SELECT 1  
         FROM #temp_member_eligibility elig   
          INNER JOIN claim  ON elig.eligibility_id = claim.eligibility_id  
          INNER JOIN claim_procedure  ON claim.claim_id = claim_procedure.claim_id  
          INNER JOIN claim_procedure_status s  ON claim_procedure.claim_procedure_status_id = s.claim_procedure_status_id  
         -- INNER JOIN claim_procedure_benefit ON claim_procedure.claim_procedure_id = claim_procedure_benefit.claim_procedure_id AND claim_procedure_benefit.deleted = 0  
          INNER JOIN voucher_claim_procedure_map  ON voucher_claim_procedure_map.claim_procedure_id = claim_procedure.claim_procedure_id AND voucher_claim_procedure_map.deleted = 0  
         WHERE  
          voucher_claim_procedure_map.voucher_id = @voucher_id            
          AND s.status_type <> 'DENY'  
         )  
        AND NOT EXISTS (  
         --  any claims on the EOB without an 003  
 SELECT 1  
         FROM #temp_member_eligibility elig     
          INNER JOIN claim  ON elig.eligibility_id = claim.eligibility_id  
          INNER JOIN claim_procedure  ON claim.claim_id = claim_procedure.claim_id  
         -- INNER JOIN claim_procedure_benefit ON claim_procedure.claim_procedure_id = claim_procedure_benefit.claim_procedure_id AND claim_procedure_benefit.deleted = 0  
          INNER JOIN voucher_claim_procedure_map ON voucher_claim_procedure_map.claim_procedure_id = claim_procedure.claim_procedure_id AND voucher_claim_procedure_map.deleted = 0  
          LEFT JOIN (  
           --  claims with an 003x EOB  
           SELECT DISTINCT claim.claim_id  
           FROM #temp_member_eligibility e2   
            INNER JOIN claim  ON e2.eligibility_id = claim.eligibility_id  
            INNER JOIN claim_procedure  ON claim.claim_id = claim_procedure.claim_id  
            INNER JOIN claim_procedure_eob e  ON claim_procedure.claim_procedure_id = e.claim_procedure_id  
           -- INNER JOIN claim_procedure_benefit ON claim_procedure.claim_procedure_id = claim_procedure_benefit.claim_procedure_id AND claim_procedure_benefit.deleted = 0  
            INNER JOIN voucher_claim_procedure_map ON voucher_claim_procedure_map.claim_procedure_id = claim_procedure.claim_procedure_id AND voucher_claim_procedure_map.deleted = 0  
           WHERE  
            voucher_claim_procedure_map.voucher_id = @voucher_id  
            AND e.eob_id IN ( 3,524,581,815,1584 ) -- EOB 003x  
          ) dupes ON claim.claim_id = dupes.claim_id  
         WHERE  
          voucher_claim_procedure_map.voucher_id = @voucher_id  
          AND dupes.claim_id IS NULL  
         )  
         BEGIN  
          SET @suppress_eob = 1  
         END  
		 -- mjp 06/07/2024 end 

        END -- if suppress eob = 0  
         
       --END  -- suppress 003s  
        
      END  -- look for member obligations  
      
     END -- force to print = 0   
      
   end -- if doc_type= eob  
---- begin and end are good to here   

  IF @suppress_eob = 1  
      BEGIN 
	
		-- mjp 06/07/2024 start 

		IF EXISTS (  
		 SELECT 1  
		 FROM #temp_member_eligibility e   
		  INNER JOIN claim  ON e.eligibility_id = claim.eligibility_id  
		  INNER JOIN claim_procedure ON claim.claim_id = claim_procedure.claim_id  
		  INNER JOIN claim_procedure_eob cpe  ON claim_procedure.claim_procedure_id = cpe.claim_procedure_id  
		  INNER JOIN eob  ON eob.eob_id = cpe.eob_id  
		  INNER JOIN voucher_claim_procedure_map  ON voucher_claim_procedure_map.claim_procedure_id = claim_procedure.claim_procedure_id AND voucher_claim_procedure_map.deleted = 0  
		 WHERE  
		  voucher_claim_procedure_map.voucher_id = @voucher_id          
		  AND eob.override_eob_suppression = 1 )  
			SET @suppress_eob = 0 
		-- mjp 06/07/2024 end 		
   END  
  
  if @suppress_eob =0  and @claim_type_id in (12,13,18) -- the medicaid claim types 11/27/2018 elva   
   set @suppress_eob= 1   


   -- Suppress EOBs for Anthem claims with repricing flag 640 'ANTHEM REJECT ACTION CODE' - US 45512
   IF @doc_type = 'EOB'AND ISNULL(@suppress_eob, 0) = 0 
      AND EXISTS ( SELECT 1 FROM [dbo].[claim] c
	                             INNER JOIN [dbo].[claim_file_source_map] cfsm ON cfsm.claim_id = c.claim_id
	               WHERE c.claim_id = @claim_id
	                     AND cfsm.claim_file_source_id IN (15, 16)
	                     AND c.claim_repricing_flag_id = 640)
	BEGIN
		SET @suppress_eob = 1
	END

  
  --5/26/2023 Verified SN
  ---SN 5/16/23 this is for COR  if it is prudential, checkbook_id 1427 and the claim tied to the correspondence 
  -- has the eob_id 3292 we do not want to generate any correspondecne 
 
  if @doc_type = 'COR' and @checkbook_id = 1427 -- correspondence   for prudential 
  begin   
		begin
			select @corr_claim_id = claim_id from correspondence_claim_link where correspondence_id = @correspondence_id

			 if exists (select top 1
							claim_id, cp.claim_procedure_id, cpe.eob_id  from  claim_procedure  cp
         					INNER JOIN claim_procedure_eob cpe  ON cp.claim_procedure_id = cpe.claim_procedure_id  
         					where cp.claim_id = @corr_claim_id and cpe.eob_id in (3292,3906))
							goto skip_processing	-- we don't want to generate the correspondence
		end 
	END

 ----END SN
 
--  -- look for EOB remarks that must be sent to the member, can't suppress those  

  
  if @doc_type = 'COR'   
   begin   
    select @claim_member_id =member_id  
     , @subscriber_id = member_id   
     , @group_contract_id =group_contract_id  
     , @subscriber_last_name =subscriber_last_name  
     , @subscriber_first_name = subscriber_first_name  
     , @member_last_name =  member_last_name  
     , @member_first_name = member_first_name  
     , @correspondence_id = correspondence_id   
    FROM #claiminfo  
     where claiminfo_id = @record_id  

	 
    -----------------------------------------------  
    -- Get the carrier name for COR type
    -----------------------------------------------   
    SELECT TOP 1 @carrier_name = ISNULL(d.report_field_10,'')  
    FROM  
		group_contract_external_vendor_report_map m   
		INNER JOIN external_vendor_report_data d  ON m.external_vendor_report_data_id = d.external_vendor_report_data_id  
    WHERE  
		m.group_contract_id = @group_contract_id  
		AND m.deleted = 0  
		AND d.deleted = 0  
    ORDER BY m.group_contract_external_vendor_report_map_id  


	 	 -- mjp 06/07/2024 start 
		truncate table #temp_member_eligibility
		insert into #temp_member_eligibility(eligibility_id)
		select eligibility_id
		  from eligibility e
		 where e.member_id = @claim_member_id
	-- mjp 06/07/2024 end 
      
    SELECT TOP 1  
	   @addressee_name = c.addressee
      ,@member_name = 
	  		CASE WHEN c.addressee IS NOT NULL AND LTRIM(c.addressee) <> '' THEN c.addressee
				 WHEN m.first_name IS NOT NULL AND LTRIM(m.first_name) <> '' THEN m.first_name + ' ' + m.last_name 
				 ELSE s.first_name + ' ' + s.last_name 
			END
      ,@member_address1 =   
			CASE WHEN c.address_1 IS NOT NULL AND LTRIM(c.address_1) <> '' THEN c.address_1
				 WHEN m.address1 IS NOT NULL AND LTRIM(m.address1) <> '' THEN m.address1
			     ELSE s.address1
			END	 
     , @member_address2 =   
			CASE WHEN c.address_1 IS NOT NULL AND LTRIM(c.address_1) <> '' THEN c.address_2
				 WHEN m.address1 IS NOT NULL AND LTRIM(m.address1) <> '' THEN m.address2
			     ELSE s.address2
			END	 
     , @member_city =   
			CASE WHEN c.address_1 IS NOT NULL AND LTRIM(c.address_1) <> '' THEN c.city
				 WHEN m.address1 IS NOT NULL AND LTRIM(m.address1) <> '' THEN m.city
			     ELSE s.city
			END	 
     , @member_state =   
			CASE WHEN c.address_1 IS NOT NULL AND LTRIM(c.address_1) <> '' THEN c.state
				 WHEN m.address1 IS NOT NULL AND LTRIM(m.address1) <> '' THEN m.state
			     ELSE s.state
			END	 
     , @member_zip =   
			CASE WHEN c.address_1 IS NOT NULL AND LTRIM(c.address_1) <> '' THEN c.zip
				 WHEN m.address1 IS NOT NULL AND LTRIM(m.address1) <> '' THEN m.zipcode
			     ELSE s.zipcode
			END	 
     , @member_phone =   
      CASE  
      WHEN m.address1 IS NOT NULL AND LTRIM(m.address1) <> '' THEN REPLACE(REPLACE(REPLACE(COALESCE(m.phone,''),' ', ''),'(',''),')','-')  
      ELSE REPLACE(REPLACE(REPLACE(COALESCE(s.phone,''),' ', ''),'(',''),')','-')  
      END  
  --   , @eligibility_ud = e.eligibility_ud  
     , @member_eligibility_ud = e.eligibility_ud  
     , @member_ssn = s.ssn  
     ,@subscriber_group = em.employergroup_ud  
  --   , @member_group_name = em.description  
     , @subscriber_group_name  = em.reporting_group_name  
     ,@member_alt_last_name = isnull(m.alt_last_name,'')  
     ,@member_alt_first_name = isnull(m.alt_first_name,'')  
     , @subscriber_name = s.first_name + ' ' + s.last_name  
     , @subscriber_id = s.member_id  -- elva 03/02/2012  -- elva 04/11/2022 a dependant had the address set up except for zip so created and error  
     ,@subscriber_address1 = LEFT(rtrim(ltrim(ISNULL(s.address1,''))),80) --elva 04/11/2022  
     ,@subscriber_address2 = LEFT(ltrim(rtrim(ISNULL(s.address2,''))),80) -- elva 04/11/2022  
     ,@subscriber_city = LEFT(ltrim(rtrim(ISNULL(s.city,''))),30)  -- elva 04/11/2022  
     ,@subscriber_state = ISNULL(s.state,'')    -- elva 04/11/2022  
     ,@subscriber_zip = LEFT(ltrim(rtrim(ISNULL(s.zipcode,''))),5) -- elva 04/11/2022  
     , @member_privacy_type_id = m.member_privacy_type_id -- 01/23/2019  
    FROM  
     correspondence c    
     INNER JOIN correspondence_eligibility_link cml  ON c.correspondence_id = cml.correspondence_id  
     INNER JOIN eligibility e  ON cml.eligibility_id = e.eligibility_id  
     INNER JOIN employergroup em  ON e.employergroup_id = em.employergroup_id  
     INNER JOIN benefitplan bp  ON e.benefitplan_id = bp.benefitplan_id  
     INNER JOIN member m  ON m.member_id = e.member_id  
     INNER JOIN member s  ON s.member_id = e.subscriber_id  
    WHERE  
     c.correspondence_id = @correspondence_id  
     AND c.deleted = 0  
     AND cml.deleted = 0  
    ORDER BY  
     cml.correspondence_eligibility_link_id  
      
    if @primary_correspondence_link_type_id <> 4 and @record_type  <> 'PPREX'  
     set @crecipientcode =  'I'   
    else   
     set @crecipientcode =  'P'   
  
   end   
   --do we need a new master record   
  if @doc_type = 'EOB'  
   begin   
     ---------------------------------------------  
    IF @last_member_id <> @claim_member_id  
     OR @last_subscriber_id <> @claim_subscriber_member_id  
     begin   
      set @created_master_record = 0   
      set @check_run_eob_header_id = null  -- 09/09/2016 added this to create a new check_run_eob_header_id when the member id or the subscriber id changes on the claims associated with the voucher   
       
      /** elva added 03/09/2017 to print remark codes on eob **/  
      if @first_time  <> 1  -- not first time  
       begin   
        if @save_suppress_eob = 0 -- so the eob was printed   
         begin   
          exec @return_status = check_run_remarkcodedescription_redcard  
          @check_run_id,  
          @modified_user_id ,  
          @voucher_id ,  
          @last_claim_id ,  
          @claim_ud ,  
          @doc_type ,  
          @doc_id   ,  
          @line_number  output   
     
          if  @return_status <> 0  
           return @return_status   
         end   
       end   
      else  
       set @first_time = 0  
     end  
   end   
  
  if @doc_type  =  'EOB' and @created_master_record = 0    
    -----------------------------------------------  
    -- Determine The Addressee  
    -----------------------------------------------  
    begin  
     IF LEN(@member_alt_last_name) > 0  
      BEGIN  
       SET @addressee_last_name = @member_alt_last_name  
       SET @addressee_first_name = @member_alt_first_name  
       SET @addressee_name = LEFT(rtrim (ISNULL(@member_alt_first_name,'') + ' ' + @member_alt_last_name),80)  
      END  
     ELSE IF @member_privacy_type_id = 1  
      BEGIN  
       SET @addressee_last_name = @member_last_name  
       SET @addressee_first_name = @member_first_name  
       SET @addressee_name = LEFT(rtrim(ISNULL(@member_first_name,'') + ' ' + @member_last_name),80)  
      END  
     ELSE  
      BEGIN  
       SET @addressee_last_name = @subscriber_last_name  
       SET @addressee_first_name = @subscriber_first_name  
       SET @addressee_name = LEFT(rtrim(ISNULL(@subscriber_first_name,'') + ' ' + @subscriber_last_name),80)  
      END  
  
     IF LEN(RTRIM(LTRIM(@member_address1))) > 0  
      AND LEN(RTRIM(LTRIM(@member_city))) > 0  
      AND LEN(RTRIM(LTRIM(@member_state))) > 0  
      AND LEN(RTRIM(LTRIM(@member_zip))) > 0  
      BEGIN  
       SET @addressee_address1 = @member_address1  
       SET @addressee_address2 = isnull(@member_address2,'')  
       SET @addressee_city = left(rtrim(@member_city),30)  
       SET @addressee_state = @member_state  
       SET @addressee_zip = left(@member_zip,5)  
      END  
     ELSE  
      BEGIN  
       SET @addressee_address1 = @subscriber_address1  
       SET @addressee_address2 = isnull(@subscriber_address2,'')  
       SET @addressee_city = left(rtrim(@subscriber_city),30)  
       SET @addressee_state = @subscriber_state  
       SET @addressee_zip = left(@subscriber_zip,5)  
      END  
  
     SET @addressee_phone = LEFT(COALESCE(@member_phone,@subscriber_phone,''),12)  
  
     IF LEN(@member_ssn) > 0 SET @addressee_ssn = @member_ssn  
     ELSE SET @addressee_ssn = @subscriber_ssn  
   end -- if eob  or cor   
  
-- begin and end through here   
  if @doc_type = 'EOP'  and @check_run_eop_header_id is null  
   begin   
    set @created_master_record = 0   
     
   -----------------------------------------------  
   -- Determine The Addressee  
   -----------------------------------------------  
    IF @checkbook_check_id IS NOT NULL  
     BEGIN  
      -- check attached for vendor  
      SET @addressee_name = @check_name  
      SET @addressee_address1 = @check_address1  
      SET @addressee_address2 = ltrim(rtrim(@check_address2))  
      --IF @addressee_address2 = '' set @addressee_address2 = null  
      SET @addressee_city = left(rtrim(@check_city),30)  
      SET @addressee_state = @check_state  
      SET @addressee_zip = left(@check_zip,5)  
      SET @addressee_phone = @vendor_phone -- there is no @check_phone so use @vendor_phone  
     END  
    ELSE  
     BEGIN  
      -- no check attached for vendor  
      SET @addressee_name = @vendor_name  
      SET @addressee_address1 = @vendor_address1  
      SET @addressee_address2 = ltrim(rtrim(isnull(@vendor_address2,'')))  
      --IF @addressee_address2 = '' set @addressee_address2 = null  
      SET @addressee_city = left(rtrim(@vendor_city),30)  
      SET @addressee_state = @vendor_state  
      SET @addressee_zip = left(@vendor_zip,5)  
      SET @addressee_phone = @vendor_phone  
     END  
   end -- eop and null   
  
  if @doc_type = ('COR') and @created_master_record = 0    
   begin   
    if @crecipientcode = 'I'  -- the document is being sent to the member   
     -----------------------------------------------  
     -- Determine The Addressee  
     -----------------------------------------------  
     begin
	  IF LEN(@addressee_name) > 0
		BEGIN
			SET @addressee_last_name = @member_last_name 
			SET @addressee_first_name = @member_first_name
			SET @addressee_name = LEFT(rtrim(@addressee_name),80) 
		END
      ELSE IF LEN(@member_alt_last_name) > 0  
       BEGIN  
			SET @addressee_last_name = @member_alt_last_name  
			SET @addressee_first_name = @member_alt_first_name  
			SET @addressee_name = LEFT(rtrim (ISNULL(@member_alt_first_name,'') + ' ' + @member_alt_last_name),80)  
       END  
      ELSE IF @member_privacy_type_id = 1  
       BEGIN  
			SET @addressee_last_name = @member_last_name  
			SET @addressee_first_name = @member_first_name  
			SET @addressee_name = LEFT(rtrim(ISNULL(@member_first_name,'') + ' ' + @member_last_name),80)  
       END  
      ELSE  
       BEGIN  
			SET @addressee_last_name = @subscriber_last_name  
			SET @addressee_first_name = @subscriber_first_name  
			SET @addressee_name = LEFT(rtrim(ISNULL(@subscriber_first_name,'') + ' ' + @subscriber_last_name),80)  
       END  
  
      IF LEN(RTRIM(LTRIM(@member_address1))) > 0  
       AND LEN(RTRIM(LTRIM(@member_city))) > 0  
       AND LEN(RTRIM(LTRIM(@member_state))) > 0  
       AND LEN(RTRIM(LTRIM(@member_zip))) > 0  
       BEGIN  
        SET @addressee_address1 = @member_address1  
        SET @addressee_address2 = isnull(@member_address2,'')  
        SET @addressee_city = left(rtrim(@member_city),30)  
        SET @addressee_state = @member_state  
        SET @addressee_zip = left(@member_zip,5)  
       END  
      ELSE  
       BEGIN  
        SET @addressee_address1 = @subscriber_address1  
        SET @addressee_address2 = isnull(@subscriber_address2,'')  
        SET @addressee_city = left(rtrim(@subscriber_city),30)  
        SET @addressee_state = @subscriber_state  
        SET @addressee_zip = left(@subscriber_zip,5)  
       END  
  
      SET @addressee_phone = LEFT(COALESCE(@member_phone,@subscriber_phone,''),12)  
  
      IF LEN(@member_ssn) > 0 SET @addressee_ssn = @member_ssn  
      ELSE SET @addressee_ssn = @subscriber_ssn  
     end -- insured document   
    else   
     -- provider document   
     begin   
      SET @addressee_name = @vendor_name  
      SET @addressee_address1 = @vendor_address1  
      SET @addressee_address2 = ltrim(rtrim(isnull(@vendor_address2,'')))  
      --IF @addressee_address2 = '' set @addressee_address2 = null  
      SET @addressee_city = left(rtrim(@vendor_city),30)  
      SET @addressee_state = @vendor_state  
      SET @addressee_zip = left(@vendor_zip,5)  
      SET @addressee_phone = @vendor_phone  
     END  
   end -- if doc type = 'cor'  
  
 if @suppress_eob = 1 goto Create_EOB_Header_record   
 if @suppress_eop = 1  goto Create_EOP_Header_record  -- added 10/30/2019 elva   
 
 -- #44757 added 01/12/2026, added community 64, 65
 if @check_run_community_id in (50,55,57,58,64,65) and  @doc_type = 'COR' and  @crecipientcode =  'P'  and @cor_name <> 'Pesrenal' -- modified 01/23/2019   --11/03/2022 SN added 57,58  Check with ELVA if we need to do for COR?
 goto skip_processing  -- added 10/30/2019 correspondence for vendors will not print for check_run_community nextera 08/19/2021 added 55  
 if @doc_type = 'MAN' and @checkbook_check_id is null goto skip_processing  -- added 10/30/2019 if it is a manual refund dont process it.    
  
 if @doc_type = 'MAN'  
  begin   
   select @group_contract_id =group_contract_id  
    , @manual_ap_entry_id = manual_ap_entry_id   
   FROM #claiminfo  
    where claiminfo_id = @record_id  
  
  end   
  --a master record needs to be created   
 if @created_master_record = 0  
  BEGIN   
  --if @first_time = 1   
  -- set @first_time =0  
  --else   
  -- incriment the doc counter   
   set @doccounter = convert(int, substring(@doc_id, 20,6) )  
   set @doccounter = @doccounter + 1   
   set @workfield = cast(@doccounter as varCHAR(6))  
   set @workfield = replicate('0',6-len(@workfield)) + rtrim(@workfield)  
   set @doc_id = substring(@doc_id, 1,19)   
   set @doc_id = rtrim(@doc_id) + @workfield  
  
   set @servicelinesequence = 0 -- it will incriment for each service line on the eob or eop   
  
   set @first_claim = 1  
     
   set @addressee_zip = left(isnull(@addressee_zip,''),5)  
    
   -- Set cRecipientCode (I = Insured, P = Provider, O = Other)
   SELECT @crecipientcode = CASE WHEN @doc_type = 'EOB' THEN 'I'
                                 WHEN @doc_type = 'EOP' THEN 'P'
								 WHEN @doc_type = 'MAN' AND @voucher_member_id IS NOT NULL THEN 'I'
								 WHEN @doc_type = 'MAN' AND @voucher_member_id IS NULL THEN 'O'
							ELSE @crecipientcode END


	-- Set cDocumentType
	SELECT @cDocumentType = CASE WHEN @doc_type = 'EOB' AND @check_attached_for_member = 1 AND @ach = 0 THEN '009' -- Explanation of benefits 
								 WHEN @doc_type = 'EOB' AND @check_attached_for_member = 1 AND @ach = 1 THEN '008' -- Explanation of benefits w/check
								 WHEN @doc_type = 'EOB' AND @check_attached_for_member = 0  THEN '008'             -- Explanation of benefits w/check 
								 WHEN @doc_type = 'EOP' AND @checkbook_check_id IS NULL THEN '010'                 -- remittance advice  
								 WHEN @doc_type = 'EOP' AND @checkbook_check_id IS NOT NULL THEN '011'             -- remittance advice w/check    
								 WHEN @doc_type = 'MAN' THEN '003'                                                 -- check (administration or manual)
								 WHEN @doc_type = 'COR' THEN '005'                                                 -- form letter
							END

   
   -- Set cClaimType   
   SELECT @redcard_claim_type = CASE LEFT(@claim_type ,3)  
									 WHEN 'MED' THEN 'MED'  
									 WHEN 'DEN' THEN 'DEN'  
									 WHEN 'VIS' THEN 'VIS'  
									 WHEN 'STD' THEN 'STD'  
									 WHEN 'FLE' THEN 'FLX'  
									 WHEN 'LIF' THEN 'LIf'  
									 WHEN 'LTD' THEN 'LTD'  
								ELSE 'OT1' END   


   -- Set cOpenField1 -- 06/22/2018 print the voucher_payment_id as the barcode 
   if @barcode is null set @barcode = '' 
   
   
   -- Set cOpenField2 -- 03/19/2024 it will be used for Erisa values
   DECLARE @erisa_char CHAR(20) 

   if @erisa = 1 
		set @erisa_char = 'Y'
	else 
		set @erisa_char = 'N'


   --Set  cForceACoverSheet, cBinInsertCode1 
   DECLARE @cForceACoverSheet CHAR(1) = ''

   if @doc_type = 'EOB' -- force a cover sheet  
    set @cForceACoverSheet = 'T'  


   -- 46449 Populate Payee NPI for claim-based documents only
   SET @payee_npi = ''
   IF @doc_type IN ('EOB', 'EOP')
   BEGIN
       SELECT @payee_npi = LEFT(LTRIM(RTRIM(ISNULL(c.billing_provider_npi, ''))), 10)
       FROM dbo.claim c
       WHERE c.claim_id = @claim_id
   END

   -- ============ INSERT FIELDS INTO 00 MASTER RECORD TABLE ============ --
   DECLARE @masterTable AS [dbo].[check_run_00_masterdelivery_type]
   DELETE FROM @masterTable
   
   INSERT INTO @masterTable                                                      
   SELECT                                                                     
		 '00'	                          -- cRecordType                                             
		,'64'                             -- cRecordVersion					
		,ISNULL(@doc_id, '')	          -- cDocId			
		,ISNULL(@addressee_name, '')	  -- cName			
		,ISNULL(@addressee_attn, '')	  -- cName2			
		,ISNULL(@addressee_address1, '')  -- cAddress1		
		,ISNULL(@addressee_address2, '')  -- cAddress2		
		,''	                              -- cAddress3						
		,''	                              -- cAddress4						
		,ISNULL(@addressee_city, '')	  -- cCity									
		,ISNULL(@addressee_state, '')	  -- cState								
		,ISNULL(@addressee_zip, '')  	  -- cZip									
		,''	                              -- cAltConsolidationKey
		,''                               -- cAltEpisodicMergeKey
		,''	                              -- cSortKey									
		,''	                              -- cInternationalCityOrTown					
		,''	                              -- cInternationalProvidenceOrTerritory		
		,''	                              -- cInternationalPostalCode					
		,''	                              -- cInternationalCountry						
		,''	                              -- cEMailAddress								
		,''                               -- cEmailAddressForNotification
		,ISNULL(@crecipientcode, '')	  -- cRecipientCode						   							
		,ISNULL(@cDocumentType, '')	      -- cDocumentType							   			
		,ISNULL(@redcard_claim_type, '')  -- cClaimType						   						
		,''	                              -- cRICode															   							
		,''	                              -- cDeliveryType
		,''                               -- cEarlyDelivery
		,''                               -- cSaturdayDelivery
		,''                               -- cSignatureRequired
		,''	                              -- cHoldCode														   								
		,''	                              -- cClientCode														   							
		,''	                              -- cTestFlag	
		,''	                              -- cPurgeFlag
		,''	                              -- cPurgeReason
		,''	                              -- cIsRegulatory
		,''	                              -- cRuleEffectiveDate												   						
		,''	                              -- cUseProposed														   					
		,''	                              -- cOverrideDistributionRule										   								
		,''	                              -- cBillingCode														   							
		,''	                              -- cOverlayReportId													   								
		,''	                              -- cOverlayInstruction												   							
		,ISNULL(@barcode, '')	          -- cOpenField1									   							
		,ISNULL(@erisa_char, '')	      -- cOpenField2								   							
		,ISNULL(@carrier_name, '')	      -- cOpenField3								   					
		,''								  -- cDocumentIndex1													   							
		,''								  -- cDocumentIndex2													   				
		,''								  -- cDocumentIndex3													   							
		,''								  -- cDocumentIndex4													   						
		,''								  -- cDocumentIndex5														   						
		,''								  -- cDocumentIndex6														   						
		,''								  -- cDocumentIndex7														   						
		,''								  -- cDocumentIndex8														   						
		,''								  -- cDocumentIndex9														   						
		,''								  -- cDocumentIndex10													   						
		,''								  -- cContentDescription													   						
		,''	                              -- cDoNotConsolidateFlag											   					
		,''	                              -- cIssuanceCode													   							
		,''	                              -- cOriginalFileFormat												   							
		,''	                              -- cTranslationId												   							
		,''	                              -- cIsPreAuth														   							
		,''	                              -- cIsDirDeposit													   						
		,''	                              -- cSimplexDuplex													   						
		,''	                              -- cReportingRollupValue1											   						
		,''	                              -- cReportingRollupValue2											   						
		,''	                              -- cReportingRollupValue3											   					
		,''	                              -- cReportingRollupValue4											   					
		,''	                              -- cReportingRollupValue5											   					
		,''	                              -- cReportingRollupValue6											   					
		,''	                              -- cReportingRollupValue7											   					
		,''	                              -- cReportingRollupValue8											   						
		,''	                              -- cReportingRollupValue9											   					
		,''	                              -- cReportingRollupValue10											   					
		,''	                              -- cAdditionalDuplicateFileDetectionValue											   					
		,''	                              -- cDuplicateDocumentDetectionValue											   					
		,ISNULL(@cForceACoverSheet, '')	  -- cForceACoverSheet					   							
		,''	                              -- cBinInsertCode1													   					
		,''	                              -- cBinInsertCode2													   						
		,''	                              -- cBinInsertCode3													   							
		,''	                              -- cBinInsertCode4													   							
		,''						          -- cPhoneNumber														   
		,''						          -- cMobilePhoneNumberForNotification														   
		,''						          -- cUseReducedPdfPage												   			
		,''						          -- cVendorInsertPageCount											   			
		,''						          -- cIsAssessmentEOB													   			
		,''						          -- cEPayType														   			
		,''						          -- cHIN																   			
		,''						          -- cNAICCode														   			
		,''						          -- cVendorTransactionId												   			
		,''						          -- cVendorInsertPageType											   			
		,''						          -- cStatementDateStart												   			
		,''						          -- cStatementDateEnd												   			
		,''						          -- cIsEpisodic										
		,''						          -- cClaimsSystem											
		,''						          -- cBusinessSLAStartDate													
		,''						          -- cBusinessSLAStartTime										
		,'WebTPA'	                      -- cPayerName											
		,'752611444'	                  -- cPayerTIN																
		,''	                              -- cPayerId																
		,'6535 State Hwy 161, Suite 100'  -- cPayerAddress		46648											
		,''	                              -- cPayerAddress2													
		,'IRVING'	                      -- cPayerCity																				
		,'TX'	                          -- cPayerState																
		,'75039'	                      -- cPayerZip																			
		,''	                              -- cPayerCountry																			
		,'tech.operations@webtpa.com'	  -- cPayerTechContactName																			
		,'8775932872'	                  -- cPayerTechContactPhone																	
		,'FINANCE@WEBTPA.COM'	          -- cPayerTechContactEmail																		
		,''                               -- cClaimsSystemVersion							
		,''                               -- cSuppressEraHardCopy							
		,''                               -- cSupplementDeliveryPriority							
		,''                               -- c835PLBProviderID										
		,''                               -- c835PLBFiscalPeriodDate									
		,''                               -- c835PLBAdjustmentReasonCode1					
		,''                               -- c835PLBAdjustmentID1							
		,''                               -- c835PLBAdjustmentAmount1								
		,''                               -- c835Option							
		,''                               -- c835PLBAdjustmentReasonCode2		
		,''                               -- c835PLBAdjustmentID2				
		,''                               -- c835PLBAdjustmentAmount2		
		,''                               -- c835PLBAdjustmentReasonCode3	
		,''                               -- c835PLBAdjustmentID3			
		,''                               -- c835PLBAdjustmentAmount3			
		,''                               -- c835PLBAdjustmentReasonCode4		
		,''                               -- c835PLBAdjustmentID4				
		,''                               -- c835PLBAdjustmentAmount4		
		,''                               -- c835PLBAdjustmentReasonCode5	
		,''                               -- c835PLBAdjustmentID5				
		,''                               -- c835PLBAdjustmentAmount5			
		,''                               -- c835PLBAdjustmentReasonCode6	
		,''                               -- c835PLBAdjustmentID6				
		,''                               -- c835PLBAdjustmentAmount6		
		,''                               -- cCleverLetterMatch					
		,''                               -- cPlainTextConsolidationKey			
		,''                               -- cPlainTextEpisodicMergeKey			
		,''                               -- cAlternateState					
		,''                               -- cDataRoleSecurity					
		,''                               -- cTraceNumber						
		,''                               -- cInboundKey							
		,''                               -- cAdvancedEOB						
		,''                               -- cPayeeTaxId							
		,''                               -- cPaymentRoutingSubTaxId				
		,ISNULL(@payee_npi, '')           -- cPayeeNPI -- 46449							
		,''                               -- cPayerContactName					
		,''                               -- cPostalCodeExtension				
		,''                               -- cPDFID1								
		,''                               -- cPDFID2								
		,''                               -- cPDFID3								
		,''                               -- cPDFID4								
		,''                               -- cPDFID5		
		,''                               -- cAutomotiveCorrection	
		,''                               -- cBypass835Creation	
		,''                               -- cRecord43UsageMode	
		,''                               -- cEpayEnrollmentId	    
		,ISNULL(@QPA_IDR_Trigger, '')     -- cOpenField4	        
		,''                               -- cOpenField5	        
		,''                               -- cOpenField6	        
		,''                               -- cOpenField7	        
		,''                               -- cOpenField8	        
		,''                               -- cOpenField9	        
		,''                               -- cOpenField10	        
   																	
   
    SET @record = (SELECT TOP 1
   		cRecordType                            + @tab +
   		cRecordVersion						   + @tab +
   		cDocId								   + @tab +
   		cName								   + @tab +
   		cName2								   + @tab +
   		cAddress1							   + @tab +
   		cAddress2							   + @tab +
   		cAddress3							   + @tab +
   		cAddress4							   + @tab +
   		cCity								   + @tab +
   		cState								   + @tab +
   		cZip								   + @tab +
   		cAltConsolidationKey				   + @tab +
   		cAltEpisodicMergeKey				   + @tab +
   		cSortKey							   + @tab +
   		cInternationalCityOrTown			   + @tab +
   		cInternationalProvidenceOrTerritory	   + @tab +
   		cInternationalPostalCode			   + @tab +
   		cInternationalCountry				   + @tab +
   		cEMailAddress						   + @tab +
   		cEmailAddressForNotification		   + @tab +
   		cRecipientCode						   + @tab +
   		cDocumentType						   + @tab +
   		cClaimType						   	   + @tab +
   		cRICode								   + @tab +
   		cDeliveryType						   + @tab +
   		cEarlyDelivery						   + @tab +
   		cSaturdayDelivery					   + @tab +
   		cSignatureRequired					   + @tab +
   		cHoldCode							   + @tab +
   		cClientCode							   + @tab +
   		cTestFlag							   + @tab +
   		cPurgeFlag							   + @tab +
   		cPurgeReason						   + @tab +
   		cIsRegulatory						   + @tab +
   		cRuleEffectiveDate					   + @tab +
   		cUseProposed						   + @tab +
   		cOverrideDistributionRule			   + @tab +
   		cBillingCode						   + @tab +
   		cOverlayReportId					   + @tab +
   		cOverlayInstruction					   + @tab +
   		cOpenField1							   + @tab +
   		cOpenField2							   + @tab +
   		cOpenField3							   + @tab +
   		cDocumentIndex1						   + @tab +
   		cDocumentIndex2						   + @tab +
   		cDocumentIndex3						   + @tab +
   		cDocumentIndex4						   + @tab +
   		cDocumentIndex5						   + @tab +
   		cDocumentIndex6						   + @tab +
   		cDocumentIndex7						   + @tab +
   		cDocumentIndex8						   + @tab +
   		cDocumentIndex9						   + @tab +
   		cDocumentIndex10					   + @tab +
   		cContentDescription					   + @tab +
   		cDoNotConsolidateFlag				   + @tab +
   		cIssuanceCode						   + @tab +
   		cOriginalFileFormat					   + @tab +
   		cTranslationId						   + @tab +
   		cIsPreAuth							   + @tab +
   		cIsDirDeposit						   + @tab +
   		cSimplexDuplex						   + @tab +
   		cReportingRollupValue1				   + @tab +
   		cReportingRollupValue2				   + @tab +
   		cReportingRollupValue3				   + @tab +
   		cReportingRollupValue4				   + @tab +
   		cReportingRollupValue5				   + @tab +
   		cReportingRollupValue6				   + @tab +
   		cReportingRollupValue7				   + @tab +
   		cReportingRollupValue8				   + @tab +
   		cReportingRollupValue9				   + @tab +
   		cReportingRollupValue10				   + @tab +
   		cAdditionalDuplicateFileDetectionValue + @tab +
   		cDuplicateDocumentDetectionValue	   + @tab +
   		cForceACoverSheet					   + @tab +
   		cBinInsertCode1						   + @tab +
   		cBinInsertCode2						   + @tab +
   		cBinInsertCode3						   + @tab +
   		cBinInsertCode4						   + @tab +
   		cPhoneNumber						   + @tab +
   		cMobilePhoneNumberForNotification	   + @tab +
   		cUseReducedPdfPage					   + @tab +
   		cVendorInsertPageCount				   + @tab +
   		cIsAssessmentEOB					   + @tab +
   		cEPayType							   + @tab +
   		cHIN								   + @tab +
   		cNAICCode							   + @tab +
   		cVendorTransactionId				   + @tab +
   		cVendorInsertPageType				   + @tab +
   		cStatementDateStart					   + @tab +
   		cStatementDateEnd					   + @tab +
   		cIsEpisodic							   + @tab +
   		cClaimsSystem						   + @tab +
   		cBusinessSLAStartDate				   + @tab +
   		cBusinessSLAStartTime				   + @tab +
   		cPayerName							   + @tab +
   		cPayerTIN							   + @tab +
   		cPayerId							   + @tab +
   		cPayerAddress						   + @tab +
   		cPayerAddress2						   + @tab +
   		cPayerCity							   + @tab +
   		cPayerState							   + @tab +
   		cPayerZip							   + @tab +
   		cPayerCountry						   + @tab +
   		cPayerTechContactName				   + @tab +
   		cPayerTechContactPhone				   + @tab +
   		cPayerTechContactEmail				   + @tab +
   		cClaimsSystemVersion				   + @tab +
   		cSuppressEraHardCopy				   + @tab +
   		cSupplementDeliveryPriority			   + @tab +
   		c835PLBProviderID					   + @tab +
   		c835PLBFiscalPeriodDate				   + @tab +
   		c835PLBAdjustmentReasonCode1		   + @tab +
   		c835PLBAdjustmentID1				   + @tab +
   		c835PLBAdjustmentAmount1			   + @tab +
   		c835Option							   + @tab +
   		c835PLBAdjustmentReasonCode2		   + @tab +
   		c835PLBAdjustmentID2				   + @tab +
   		c835PLBAdjustmentAmount2			   + @tab +
   		c835PLBAdjustmentReasonCode3		   + @tab +
   		c835PLBAdjustmentID3				   + @tab +
   		c835PLBAdjustmentAmount3			   + @tab +
   		c835PLBAdjustmentReasonCode4		   + @tab +
   		c835PLBAdjustmentID4				   + @tab +
   		c835PLBAdjustmentAmount4			   + @tab +
   		c835PLBAdjustmentReasonCode5		   + @tab +
   		c835PLBAdjustmentID5				   + @tab +
   		c835PLBAdjustmentAmount5			   + @tab +
   		c835PLBAdjustmentReasonCode6		   + @tab +
   		c835PLBAdjustmentID6				   + @tab +
   		c835PLBAdjustmentAmount6			   + @tab +
   		cCleverLetterMatch					   + @tab +
   		cPlainTextConsolidationKey			   + @tab +
   		cPlainTextEpisodicMergeKey			   + @tab +
   		cAlternateState						   + @tab +
   		cDataRoleSecurity					   + @tab +
   		cTraceNumber						   + @tab +
   		cInboundKey							   + @tab +
   		cAdvancedEOB						   + @tab +
   		cPayeeTaxId							   + @tab +
   		cPaymentRoutingSubTaxId				   + @tab +
   		cPayeeNPI							   + @tab +
   		cPayerContactName					   + @tab +
   		cPostalCodeExtension				   + @tab +
   		cPDFID1								   + @tab +
   		cPDFID2								   + @tab +
   		cPDFID3								   + @tab +
   		cPDFID4								   + @tab +
   		cPDFID5								   + @tab +
   		cAutomotiveCorrection				   + @tab +
   		cBypass835Creation		               + @tab +
   		cRecord43UsageMode		               + @tab +
   		cEpayEnrollmentId	                   + @tab +
   		cOpenField4	        	               + @tab +
   		cOpenField5	        	               + @tab +
   		cOpenField6	        	               + @tab +
   		cOpenField7	        	               + @tab +
   		cOpenField8	        	               + @tab +
   		cOpenField9	        	               + @tab +
   		cOpenField10	                       + @tab 
	FROM @masterTable
	)

	-- Save data fields and check run parameters 
	EXEC [dbo].[check_run_00_masterdelivery_log_redcard]
	@check_run_id,
	@voucher_payment_rule_id,   
	@checkbook_id,   
	@last_checkbook_id,         
	@doc_type,   
	@doc_id,  
	@correspondence_id,    
	@record_type,  
	@cor_name,   
	@primary_correspondence_link_type_id,
	@masterTable

	-- Save record to check run batch 
	EXEC @return_status = check_run_record_insert_redcard @check_run_id, @line_number OUTPUT, @record, 1, @modified_user_id  

	
    IF @return_status <> 0 
    BEGIN  
       -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
       SET @error_message = CONCAT('Fatal Error 7 - An error in check_run_record_insert_redcard has occured with masterdelivery: ', ISNULL(@record, 'NULL'), ' claim_id: ', ISNULL(@claim_id, 0))
	   RAISERROR(@error_message, 16, 1) 
    END  
  
  
   set @created_master_record = 1   
  
  	--#41961
	DECLARE @masterextension1Table AS [dbo].[check_run_16_masterextension1_type]
	DELETE FROM @masterextension1Table
	
	INSERT INTO @masterextension1Table                                                      
	SELECT                                                                     
		 '16'								-- cRecordType                                             
	    ,'07'								-- cRecordVersion					
	    ,ISNULL(@doc_id, '')				-- cDocId			
		,ISNULL(@return_phone, '')			-- cCustomerServiceInfo1
		,ISNULL(@return_fax, '')			-- cCustomerServiceInfo2
		,''									-- cCustomerServiceInfo3
		,''									-- cCustomerServiceInfo4
		,''									-- cReturnLogo
		,''									-- cReturnStyle
		,ISNULL(@return_name, '')			-- cReturnName
		,ISNULL(@return_address1, '')		-- cReturnAddress1
		,ISNULL(@return_address2, '')		-- cReturnAddress2
		,''									-- cReturnAddress3
		,ISNULL(@return_city, '')			-- cReturnAddressCity
		,ISNULL(@return_state, '')			-- cReturnAddressState
		,ISNULL(@return_zip, '')			-- cReturnAddressZip
		,''									-- cReturnAddressZipExtension
		,''									-- cGroupLogo
		,''									-- cWatermark1
		,''									-- cWatermark2
		,''									-- cCopyFlag
		,''									-- cWebAddress
		,''									-- cReturnInternationalCityOrTown
		,''									-- cReturnInternationalProvinceOrTerritory
		,''									-- cReturnInternationalPostalCode
		,''									-- cReturnInternationalCountry	
		
	SET @recext = (SELECT TOP 1
		cRecordType									+ @tab +
		cRecordVersion								+ @tab +
		cDocId										+ @tab +
		cCustomerServiceInfo1						+ @tab +
		cCustomerServiceInfo2						+ @tab +
		cCustomerServiceInfo3						+ @tab +
		cCustomerServiceInfo4						+ @tab +
		cReturnLogo									+ @tab +
		cReturnStyle								+ @tab +
		cReturnName									+ @tab +
		cReturnAddress1								+ @tab +
		cReturnAddress2								+ @tab +
		cReturnAddress3								+ @tab +
		cReturnAddressCity							+ @tab +
		cReturnAddressState							+ @tab +
		cReturnAddressZip							+ @tab +
		cReturnAddressZipExtension					+ @tab +
		cGroupLogo									+ @tab +
		cWatermark1									+ @tab +
		cWatermark2									+ @tab +
		cCopyFlag									+ @tab +
		cWebAddress									+ @tab +
		cReturnInternationalCityOrTown				+ @tab +
		cReturnInternationalProvinceOrTerritory		+ @tab +
		cReturnInternationalPostalCode				+ @tab +
		cReturnInternationalCountry					+ @tab 
		FROM @masterextension1Table					
		)

	-- Save data fields and check run parameters masterextension1
	EXEC [dbo].[check_run_16_masterextension1_log_redcard]
	@check_run_id,
	@voucher_payment_rule_id,   
	@checkbook_id,   
	@last_checkbook_id,         
	@doc_type,   
	@doc_id,  
	@correspondence_id,    
	@record_type,  
	@cor_name,   
	@primary_correspondence_link_type_id,
	@masterextension1Table

  
   EXEC @return_status = check_run_record_insert_redcard @check_run_id, @line_number OUTPUT, @recext, 1, @modified_user_id  
    IF @return_status <> 0  
    BEGIN  
        -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
        SET @error_message = CONCAT('Fatal Error 8 - An error in check_run_record_insert_redcard has occured with masterextension: ', ISNULL(@recext, 'NULL'), ' claim_id: ', ISNULL(@claim_id, 0))
	    RAISERROR(@error_message, 16, 1) 
    END  
  end -- create master record  
 else   
  set @first_claim = 0   
  
--end   
  
 Create_EOB_Header_record:  
 -- whether it is suppressed or not we will create the EOB Header_record   
---- ends are good through here   
  
  if @doc_type = 'EOB'   
   begin   
    -----------------------------------------------  
    -- See if this needs a new EOB  
    -----------------------------------------------  
    IF @last_member_id <> @claim_member_id  
     OR @last_subscriber_id <> @claim_subscriber_member_id  
  
     begin   
      -- insert attachment record whihc will be used to retrieve data via web api call   
      EXEC @return_status = next_finance_document_get @eob_number OUTPUT  
      IF @return_status <> 0  
      BEGIN  
           -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
           SET @error_message = CONCAT('Fatal Error 9 - An error in next_finance_document_get has occured with claim_ud: ', ISNULL(@claim_ud, 'NULL'))
	       RAISERROR(@error_message, 16, 1) 
      END  
  
      SET @attachment_name = @eob_number + '.PDF'  
      EXEC check_run_attachment_ins @check_run_id,  
        1,  
        @attachment_name,  
        @voucher_payment_id,  
        @modified_user_id,  
        @check_run_attachment_id output  
      IF @@ERROR <> 0       
      BEGIN  
           -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
           SET @error_message = CONCAT('Fatal Error 10 - An error in check_run_attachment_ins has occured with attachment_name: ', ISNULL(@attachment_name, 'NULL'))
	       RAISERROR(@error_message, 16, 1) 
      END  
     END -- different member  
   end -- if eob  
  
  
if @doc_type = 'EOB' and (@check_run_eob_header_id is null or @save_suppress_eob <> @suppress_eob) -- elva 11/27/2018 if one claim was suppressed and one wasn't we want a new check run eob header id  
 begin   
  -----------------------------------------------  
  -- Create check_run_eob_header record even if it is suppressed the header info is saved.  It can be used   
  -- to display a virtual eob if it was suppressed   
  -----------------------------------------------  
      
  INSERT INTO check_run_eob_header (  
    check_run_account_header_id  
   , voucher_id  
   , voucher_payment_id  
   , is_suppressed  
   , addressee_ssn  
   , addressee_last_name  
   , addressee_first_name  
   , addressee_address1  
   , addressee_address2  
   , addressee_city  
   , addressee_state  
   , addressee_zip  
   , addressee_phone  
   , member_id  
   , member_ssn  
   , member_last_name  
   , member_first_name  
   , member_eligibility_ud  
   , subscriber_member_id  
   , subscriber_ssn  
   , subscriber_last_name  
   , subscriber_first_name  
   , subscriber_employergroup_id  
   , subscriber_employergroup_ud  
   , subscriber_employergroup_nm  
   , subscriber_benefitplan_ud  
   , check_attached_for_member  
   , checkbook_check_id  
   , check_number  
   , check_date  
   , check_amount  
   , check_vendor_id  
   , check_member_id  
   , check_tax_id  
   , check_name  
   , check_address1  
   , check_address2  
   , check_city  
   , check_state  
   , check_zip  
   , include_ERISA_message  
   , carrier_name  
   , redirect  
   , attachment_code  
   , created_user_id  
   , modified_user_id   )  
  SELECT   
    @check_run_account_header_id  
   , @voucher_id  
   , @voucher_payment_id  
   , @suppress_eob  
   , CASE WHEN LEN(@addressee_ssn) > 0 THEN @addressee_ssn ELSE convert(varchar(11), @claim_subscriber_member_id) END  -- elva 03/02/2012  
   , @addressee_last_name  
   , @addressee_first_name  
   , @addressee_address1  
   , @addressee_address2  
   , @addressee_city  
   , @addressee_state  
   , @addressee_zip  
   , @addressee_phone  
   , @claim_member_id  
   , CASE WHEN LEN(@member_ssn) > 0 THEN @member_ssn ELSE null END  
   , @member_last_name  
   , @member_first_name  
   , @member_eligibility_ud  
   , @claim_subscriber_member_id  
   , CASE WHEN LEN(@subscriber_ssn) > 0 THEN @subscriber_ssn ELSE null END  
   , @subscriber_last_name  
   , @subscriber_first_name  
   , @employergroup_id  
   , @subscriber_group  
   , @subscriber_group_name  
   , @subscriber_plan  
   , @check_attached_for_member  
   , @checkbook_check_id  
   , @check_number  
   , @check_date  
   , @check_amount  
   , @vendor_id  
   , @voucher_member_id  
   , CASE WHEN @check_attached_for_member = 1 THEN CASE WHEN LEN(@member_ssn) > 0 THEN @member_ssn ELSE null END ELSE @vendor_tax_id END  
   , @check_name  
   , @check_address1  
   , @check_address2  
   , @check_city  
   , @check_state  
   , @check_zip  
   , @ERISA  
   , @carrier_name  
   , @redirect  
   , CASE WHEN @attachment_code = '' THEN NULL ELSE @attachment_code END  
   , @modified_user_id  
   , @modified_user_id  
  
  SET @check_run_eob_header_id = SCOPE_IDENTITY()  
  -----------------------------------------------  
  -- Update Member/Subscriber Tags  
  -----------------------------------------------  
  SET @last_member_id = @claim_member_id  
  SET @last_subscriber_id = @claim_subscriber_member_id  
  set @save_suppress_eob = @suppress_eob -- added 03/09/2017  
  set @last_claim_id = @claim_id -- elva added 03/09/2017  
    
 end -- if eob and null  
  
    
 Create_EOP_Header_record:  
-- begin and end good  
 -----------------------------------------------  
 -- Is this claim suppressed?  
 -----------------------------------------------  
 SET @suppress_this_claim = 0  
 IF EXISTS (SELECT 1 FROM @suppress_claims WHERE claim_id = @claim_id AND suppress = 1)  
  SET @suppress_this_claim = 1  
   
 -----------------------------------------------  
 -- Create EOP ID  
 -- the attachment record is used for the web api call   
 -----------------------------------------------  
 if @doc_type = 'EOP' and @suppress_eop = 0   
  begin   
   EXECUTE @return_status = next_finance_document_get @eop_number OUTPUT  
   IF @return_status <> 0  
   BEGIN  
        -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
        SET @error_message = CONCAT('Fatal Error 11 - An error in next_finance_document_get has occured with claim_id: ', ISNULL(@claim_id, 0), ' claim_id: ', ISNULL(@claim_id, 0))
	    RAISERROR(@error_message, 16, 1) 
   END  
  
   IF @return_status = 0  
   BEGIN  
    SET @attachment_name = @eop_number + '.PDF'  
    EXEC check_run_attachment_ins @check_run_id,  
          2,  
          @attachment_name,  
          @voucher_payment_id,  
          @modified_user_id,  
          @check_run_attachment_id output  
    IF @@ERROR <> 0  
    BEGIN  
        -- ========== RAISE ERROR: LOG MESSAGE AND SEND EMAIL NOTIFICATION =================================
        SET @error_message = CONCAT('Fatal Error 12 - An error in check_run_attachment_ins has occured with attachment_name: ', ISNULL(@attachment_name, 'NULL'), ' claim_id: ', ISNULL(@claim_id, 0))
	    RAISERROR(@error_message, 16, 1) 
    END  
   END  
  end -- if eop and suppress  
  
 if @doc_type = 'EOP'   and @check_run_eop_header_id is null   
  begin   
   -----------------------------------------------  
   -- Create our EOP header (once)  
   -----------------------------------------------  
   --IF @suppress_eop = 0 AND @created_eop_header = 0  
   -------------------------------------------  
    --      Create EOP Header Record  
    --whether it is suppressed or not we will create the EOB Header_record.  It is used to display a virtual eop if it was suppressed   
   -------------------------------------------  
   BEGIN  
    INSERT INTO check_run_eop_header (  
      check_run_account_header_id  
     , voucher_id  
     , voucher_payment_id  
     , is_suppressed  
     , addressee_name  
     , addressee_address1  
     , addressee_address2  
     , addressee_city  
     , addressee_state  
     , addressee_zip  
     , addressee_phone  
     , vendor_id  
     , vendor_ud  
     , vendor_tax_id  
     , vendor_name  
     , vendor_address1  
     , vendor_address2  
     , vendor_city  
     , vendor_state  
     , vendor_zip  
     , vendor_phone  
     , check_attached_for_vendor  
     , checkbook_check_id  
     , check_number  
     , check_date  
     , check_amount  
     , check_name  
     , check_address1  
     , check_address2  
     , check_city  
     , check_state  
     , check_zip  
     , carrier_name  
     , redirect  
     , created_user_id  
     , modified_user_id   )  
    SELECT   
      @check_run_account_header_id  
     , @voucher_id  
     , @voucher_payment_id  
     , @suppress_eop  
     , @addressee_name  
     , @addressee_address1  
     , @addressee_address2  
     , @addressee_city  
     , @addressee_state  
     , @addressee_zip  
     , @addressee_phone  
     , @vendor_id  
     , @vendor_ud  
     , @vendor_tax_id  
     , @vendor_name  
     , @vendor_address1  
     , @vendor_address2  
     , @vendor_city  
     , @vendor_state  
     , @vendor_zip  
     , @vendor_phone  
     , CASE WHEN @checkbook_check_id IS NULL THEN 0 ELSE 1 END -- @check_attached_for_vendor  
     , @checkbook_check_id  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_number END  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_date END  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_amount END  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_name END  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_address1 END  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_address2 END  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_city END  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_state END  
     , CASE WHEN @checkbook_check_id IS NULL THEN null ELSE @check_zip END  
     , @carrier_name  
     , @redirect  
     , @modified_user_id  
     , @modified_user_id  
  
    SET @check_run_eop_header_id = SCOPE_IDENTITY()  
   END -- if eop and is null  
  end   
  
 --begin and end good   
 -- create the detail record - MAN will call this also  
  
 if @first_claim = 1   
  begin   
   set @claim_sequence = 1  
   --set @first_time = 0   
  end   
 else   
  set @claim_sequence = @claim_sequence  + 1  
  
 execute @return_status = check_run_claimnondetail_redcard @check_run_id,   
  @modified_user_id,  
  @voucher_payment_rule_id,  
  @check_run_eob_header_id output,  
  @check_run_eop_header_id output,  
  @claim_id ,  
  @doc_type ,   
  @doc_id  ,  
  @suppress_eop  ,  
  @suppress_eob ,  
  @claim_sequence output ,  
  @servicelinesequence output,   -- the serviceline numbe within the eob/eop   
  @line_number output ,  
  @attachment_name ,  
  @check_run_attachment_id,  
  @suppress_this_claim ,  
  @claim_member_id ,  
  @correspondence_id  ,  
  @record_type ,--the correspondence record type, ffl1, mprex etc.   
  @cor_name ,  -- the correspondence name PRED pdelay15 etc  
  @primary_correspondence_link_type_id ,  
  @manual_ap_entry_id ,  
  @redirect_code -- redirect code signifying which address to send the redirect to  
  
 if  @return_status <> 0  
  return @return_status 
  


  set @record_id = @record_id + 1   
end   
  
-- the end of the cursor /record reads for this voucher. If there was a check create the record now.   
 if @doc_type in ('EOB','EOP')  
  -- if it is an eob or an eop create the remark codes to print at the bottom of the eop or eob   
  begin   
   exec @return_status = check_run_remarkcodedescription_redcard  
   @check_run_id,  
   @modified_user_id ,  
   @voucher_id ,  
   @claim_id ,  
   @claim_ud ,  
   @doc_type ,  
   @doc_id   ,  
   @line_number  output   
     
   if  @return_status <> 0  
    return @return_status   
  end    
  
  --If there was a check create the record now.   
  
 if  @check_attached_for_member = 1  and @ach = 0		-- elva 02/28/2024 added to look at @ach 
  begin   
   execute @return_status = check_run_check_redcard @check_run_id,   
   @modified_user_id,  
   @voucher_id ,   
   @doc_type ,   
   @doc_id  ,  
   @checkbook_check_id,
   @claim_id,	-- Joe 01/16/2025
   @line_number output ,  
   @voucher_payment_id ,  
   @manual_number   
  
   if  @return_status <> 0  
    return @return_status   
  end  
 
 -- #44757 added 01/12/2026, added community 64, 65
 if @doc_type = 'EOP' and @check_attached_for_member = 0 and @checkbook_check_id IS NOT NULL and @check_run_community_id not in (50, 55, 57, 58, 62, 64, 65)  -- elva 12/06/2019, 08/19/2021 added 55  --11/03/2022 SN added 57,58
  begin   
   execute @return_status = check_run_check_redcard @check_run_id,   
   @modified_user_id,  
   @voucher_id ,   
   @doc_type ,   
   @doc_id  ,  
   @checkbook_check_id,
   @claim_id,	-- Joe 01/16/2025
   @line_number output ,  
   @voucher_payment_id ,  
   @manual_number   
  
   if  @return_status <> 0  
    return @return_status   
  end  
  
   
 if @doc_type = 'MAN' and @check_attached_for_member = 0 and @checkbook_check_id IS NOT NULL   
  begin   
   execute @return_status = check_run_check_redcard @check_run_id,   
   @modified_user_id,  
   @voucher_id ,   
   @doc_type ,   
   @doc_id  ,  
   @checkbook_check_id,
   @claim_id,	-- Joe 01/16/2025
   @line_number output ,  
   @voucher_payment_id ,  
   @manual_number   
  
   if  @return_status <> 0  
    return @return_status   
  end  
  
 skip_processing:  -- elva 10/30/2019  
end try  
begin catch   
     -- LOG ERROR AND SEND EMAIL =============================================================
     SET @return_status = -1
     SET @error_message = 'check_run_master_redcard fatal error 13' + CHAR(10)
     SET @error_message = CONCAT(@error_message, 'ERROR_MESSAGE: ', ERROR_MESSAGE(), ' ERROR_LINE: ', ERROR_LINE())
     
     EXEC [dbo].[finance_email_notification] @user_id, @error_message, @ProgramName, @sp_name
     RETURN @return_status

     ----------------------------------------------------------------------------------------- 
end catch  
  
return @return_status  