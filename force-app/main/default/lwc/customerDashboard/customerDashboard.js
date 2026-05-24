import { LightningElement, wire, track } from 'lwc';
import getAccountSummary from '@salesforce/apex/CommunityPortalController.getAccountSummary';

export default class CustomerDashboard extends LightningElement {
    @track summary = { assetsOwned: 0, activeWarranties: 0, openTasks: 0 };
    isLoading = true;

    @wire(getAccountSummary)
    wiredSummary({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.summary = data;
        }
    }

    get openTaskColorClass() {
        const base = 'slds-text-heading_large slds-p-top_small';
        return this.summary.openTasks > 0
            ? `${base} slds-text-color_destructive`
            : base;
    }
}