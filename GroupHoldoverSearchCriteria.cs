namespace WebTPA.GeneralManagement.DesktopUI.Features.BenefitAdministrator.GroupHoldover.Models
{
    public class GroupHoldoverSearchCriteria
    {
        public string? ParentEmployerGroupUd { get; set; }
        public string? EmployerGroupUd { get; set; }
        public string? GroupContractUd { get; set; }
        public string? BenefitPlanUd { get; set; }

        public DateTimeOffset? EffectiveDate { get; set; }
        public DateTimeOffset? ThruDate { get; set; }

        public void Reset()
        {
            ParentEmployerGroupUd = null;
            EmployerGroupUd = null;
            GroupContractUd = null;
            BenefitPlanUd = null;
            EffectiveDate = null;
            ThruDate = null;
        }

        public bool HasAtLeastOneCriteria()
        {
            return !string.IsNullOrWhiteSpace(ParentEmployerGroupUd)
                || !string.IsNullOrWhiteSpace(EmployerGroupUd)
                || !string.IsNullOrWhiteSpace(GroupContractUd)
                || !string.IsNullOrWhiteSpace(BenefitPlanUd);
        }
    }
}
