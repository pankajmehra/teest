from pathlib import Path
import hashlib
import subprocess


def git_show(path: str) -> str:
    return subprocess.check_output(
        ["git", "show", f"origin/main:{path}"],
        text=True,
        encoding="utf-8",
    )


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def git_blob_sha(text: str) -> str:
    data = text.encode("utf-8")
    header = f"blob {len(data)}\0".encode("utf-8")
    return hashlib.sha1(header + data).hexdigest()


# -----------------------------------------------------------------------------
# 00 Master: exact Story 46449 pre-QA baseline
# -----------------------------------------------------------------------------
master = git_show("check_run_master_redcard_46449_UPDATED.sql")

old_hist = " Modified 08/18/2026 PS  47283 Allow claim reversals on EOPs for all groups\n"
master = replace_once(
    master,
    old_hist,
    old_hist
    + " Modified 09/13/2026 PM  46449 QA fix - use the same Payee NPI source as Record 06 for Master and Claim Non-Detail\n",
    "master history",
)

old_var = " DECLARE @payee_npi                 varchar(10) -- 46449\n"
master = replace_once(
    master,
    old_var,
    old_var
    + " DECLARE @payee_npi_claim_id        int         -- 46449 QA fix: claim id that Record 06 will receive\n",
    "master variable",
)

anchor = """ set @first_time = 1  

 -----------------------------------------------  
 -- Determine @NSA_flag  
 -----------------------------------------------  
"""
stable_npi_block = """ set @first_time = 1  

 -- 46449 QA fix
 -- Record 06 is created after the claim loop and receives the final @claim_id processed.
 -- Resolve that same claim up front so Record 00 and every Record 01 use the exact
 -- same Payee/Billing NPI that Record 06 will report.
 SET @payee_npi = ''
 SET @payee_npi_claim_id = NULL

 IF @doc_type IN ('EOB', 'EOP')
 BEGIN
     SELECT TOP 1
         @payee_npi_claim_id = claim_id
     FROM #claiminfo
     WHERE claim_id IS NOT NULL
     ORDER BY claiminfo_id DESC

     SELECT TOP 1
         @payee_npi = SUBSTRING(ISNULL(c.billing_provider_npi, ''), 1, 10)
     FROM dbo.claim c
     INNER JOIN dbo.provider_id_map pim
         ON c.provider_id_map_id = pim.provider_id_map_id
     INNER JOIN dbo.vendor v
         ON c.vendor_id = v.vendor_id
     WHERE c.claim_id = @payee_npi_claim_id
       AND LEN(v.tax_id) > 0
       AND LEN(c.billing_provider_npi) > 0
       AND @vendor_id <> 1337149
 END

 -----------------------------------------------  
 -- Determine @NSA_flag  
 -----------------------------------------------  
"""
master = replace_once(master, anchor, stable_npi_block, "master stable NPI insertion")

old_master_lookup = """       -- 46449 Populate cPayeeNPI using the same rules as Record 06 cPayeeNPI
   SET @payee_npi = ''
   IF @doc_type IN ('EOB', 'EOP')
   BEGIN
       SELECT TOP 1
           @payee_npi = SUBSTRING(ISNULL(c.billing_provider_npi, ''), 1, 10)
       FROM dbo.claim c
       INNER JOIN dbo.provider_id_map pim
           ON c.provider_id_map_id = pim.provider_id_map_id
       INNER JOIN dbo.vendor v
           ON c.vendor_id = v.vendor_id
       WHERE c.claim_id = @claim_id
         AND LEN(v.tax_id) > 0
         AND LEN(c.billing_provider_npi) > 0
         AND @vendor_id <> 1337149
   END

"""
master = replace_once(master, old_master_lookup, "", "remove old master lookup")

old_call_tail = """  @manual_ap_entry_id ,  
  @redirect_code -- redirect code signifying which address to send the redirect to  
"""
new_call_tail = """  @manual_ap_entry_id ,  
  @redirect_code, -- redirect code signifying which address to send the redirect to  
  @payee_npi      -- 46449 QA fix: same NPI that Record 06 will report
"""
master = replace_once(master, old_call_tail, new_call_tail, "master to 01 parameter")


# -----------------------------------------------------------------------------
# 01 Claim Non-Detail: exact Story 46449 pre-QA baseline
# -----------------------------------------------------------------------------
claim = git_show("check_run_claimnondetail_redcard_46449 (1).sql")

old_claim_hist = (
    " modified 08/04/2026 46449 PM Populate Billing NPI and Rendering Physician NPI in Record 01\n"
)
claim = replace_once(
    claim,
    old_claim_hist,
    old_claim_hist
    + " modified 09/13/2026 46449 PM QA fix - cBillingNPI must use the same Payee NPI as Record 06\n",
    "claim history",
)

old_sig = """ @manual_ap_entry_id int ,  
 @redirect_code char(3)   -- code for redirect address to use  
"""
new_sig = """ @manual_ap_entry_id int ,  
 @redirect_code char(3),  -- code for redirect address to use  
 @payee_npi varchar(10) = NULL -- 46449 QA fix: Record 06 Payee NPI supplied by master
"""
claim = replace_once(claim, old_sig, new_sig, "claim signature")

old_billing = """   -- 46449 Populate cBillingNPI using the same rules as Record 06 cPayeeNPI
   SET @billing_npi = ''
   SELECT TOP 1
       @billing_npi = SUBSTRING(ISNULL(c.billing_provider_npi, ''), 1, 10)
   FROM dbo.claim c
   INNER JOIN dbo.provider_id_map pim ON c.provider_id_map_id = pim.provider_id_map_id
   INNER JOIN dbo.vendor v ON c.vendor_id = v.vendor_id
   WHERE c.claim_id = @claim_id
     AND LEN(v.tax_id) > 0
     AND LEN(c.billing_provider_npi) > 0
     AND @voucher_vendor_id <> 1337149
"""
new_billing = """   -- 46449 QA fix: cBillingNPI must be the same NPI reported on Record 06.
   -- The master SP passes that stable voucher/check-level NPI for every 01 record.
   SET @billing_npi = ISNULL(@payee_npi, '')

   -- Backward-compatible fallback for any legacy caller that does not pass @payee_npi.
   IF @payee_npi IS NULL
   BEGIN
       SELECT TOP 1
           @billing_npi = SUBSTRING(ISNULL(c.billing_provider_npi, ''), 1, 10)
       FROM dbo.claim c
       INNER JOIN dbo.provider_id_map pim ON c.provider_id_map_id = pim.provider_id_map_id
       INNER JOIN dbo.vendor v ON c.vendor_id = v.vendor_id
       WHERE c.claim_id = @claim_id
         AND LEN(v.tax_id) > 0
         AND LEN(c.billing_provider_npi) > 0
         AND @voucher_vendor_id <> 1337149
   END
"""
claim = replace_once(claim, old_billing, new_billing, "claim billing NPI")

# Verify exact content against the full QA files reviewed in ChatGPT.
expected_master_blob_sha = "6d1a8a4dd5b259d1d235990e1fee66951c83d148"
expected_claim_blob_sha = "a7c50fc013547320383d00c3e54bb453a7e8580a"
actual_master_blob_sha = git_blob_sha(master)
actual_claim_blob_sha = git_blob_sha(claim)

if actual_master_blob_sha != expected_master_blob_sha:
    raise RuntimeError(
        f"Master blob SHA mismatch: {actual_master_blob_sha} != {expected_master_blob_sha}"
    )
if actual_claim_blob_sha != expected_claim_blob_sha:
    raise RuntimeError(
        f"Claim blob SHA mismatch: {actual_claim_blob_sha} != {expected_claim_blob_sha}"
    )

Path("check_run_master_redcard_46449_QA_FIX.sql").write_text(
    master, encoding="utf-8", newline=""
)
Path("check_run_claimnondetail_redcard_46449_QA_FIX.sql").write_text(
    claim, encoding="utf-8", newline=""
)

print("Master blob SHA:", actual_master_blob_sha)
print("Claim blob SHA:", actual_claim_blob_sha)
