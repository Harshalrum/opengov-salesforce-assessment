import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyWarranties from '@salesforce/apex/CommunityPortalController.getMyWarranties';
import getAssetOptionsForCurrentAccount from '@salesforce/apex/CommunityPortalController.getAssetOptionsForCurrentAccount';
import registerWarranty from '@salesforce/apex/CommunityPortalController.registerWarranty';

const COLUMNS = [
    { label: 'Warranty Number', fieldName: 'name',      type: 'text' },
    { label: 'Asset',           fieldName: 'assetName', type: 'text' },
    { label: 'Status',          fieldName: 'status',    type: 'text',
      cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'Start Date',      fieldName: 'startDate', type: 'date-local' },
    { label: 'End Date',        fieldName: 'endDate',   type: 'date-local' },
    { label: 'Days Remaining',  fieldName: 'daysRemaining', type: 'number',
      cellAttributes: { class: { fieldName: 'daysClass' } } }
];

const STATUS_OPTIONS = [
    { label: 'Draft',   value: 'Draft'   },
    { label: 'Active',  value: 'Active'  },
    { label: 'Expired', value: 'Expired' }
];

export default class CustomerWarranties extends LightningElement {
    @track warranties = [];
    @track assetOptions = [];
    @track form = {
        assetId: '',
        status: 'Draft',
        startDate: null,
        endDate: null
    };
    @track formError;
    @track listError;
    isLoading = true;
    isSaving = false;
    isFormOpen = false;
    columns = COLUMNS;
    statusOptions = STATUS_OPTIONS;
    wiredWarrantiesResult;

    // ----- Wires -----
    @wire(getMyWarranties)
    wiredWarranties(result) {
        this.wiredWarrantiesResult = result;
        this.isLoading = false;
        if (result.data) {
            this.warranties = result.data.map(w => this.decorateWarranty(w));
            this.listError = undefined;
        } else if (result.error) {
            this.warranties = [];
            this.listError = this.reduceError(result.error);
        }
    }

    @wire(getAssetOptionsForCurrentAccount)
    wiredAssetOptions({ data, error }) {
        if (data) {
            this.assetOptions = data;
        }
    }

    // ----- Derived state -----
    get isListEmpty() {
        return !this.isLoading && !this.listError && this.warranties.length === 0;
    }
    get hasWarranties() {
        return !this.isLoading && !this.listError && this.warranties.length > 0;
    }

    decorateWarranty(w) {
        return {
            ...w,
            statusClass: w.status === 'Active'  ? 'slds-text-color_success' :
                         w.status === 'Expired' ? 'slds-text-color_destructive' : '',
            daysClass:   w.daysRemaining != null && w.daysRemaining < 30
                            ? 'slds-text-color_destructive' : ''
        };
    }

    // ----- Form interactions -----
    openForm() {
        this.formError = undefined;
        this.form = {
            assetId: '',
            status: 'Draft',
            startDate: this.today(),
            endDate: this.todayPlus(365)
        };
        this.isFormOpen = true;
    }

    closeForm() {
        if (this.isSaving) return;
        this.isFormOpen = false;
        this.formError = undefined;
    }

    handleFieldChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        // Defensive: only assign to known form keys, so a future HTML/JS
        // mismatch surfaces as a console warning instead of silently
        // dropping the user's input.
        if (!(field in this.form)) {
            // eslint-disable-next-line no-console
            console.warn(
                `customerWarranties: change event for unknown field "${field}". ` +
                `Allowed keys: ${Object.keys(this.form).join(', ')}`
            );
            return;
        }
        this.form = { ...this.form, [field]: value };

    }

    // ----- The main event: submit the form -----
    async handleSubmit() {
        this.formError = undefined;

        // Client-side guard - quick fail before the round trip
        if (!this.form.assetId) {
            this.formError = 'Please select an asset.';
            return;
        }
        if (!this.form.status) {
            this.formError = 'Please select a status.';
            return;
        }

        this.isSaving = true;
        try {
            const saved = await registerWarranty({
                assetId:   this.form.assetId,
                status:    this.form.status,
                startDate: this.form.startDate,
                endDate:   this.form.endDate
            });

            // SUCCESS!
            this.dispatchEvent(new ShowToastEvent({
                title: 'Warranty Registered',
                message: `${saved.name} has been registered successfully.`,
                variant: 'success'
            }));
            this.isFormOpen = false;
            await refreshApex(this.wiredWarrantiesResult);
        } catch (e) {
            // The Apex controller already cleaned the message via FlowErrorHandler.
            // We just need to extract it from the AuraHandledException body.
            this.formError = this.reduceError(e);
        } finally {
            this.isSaving = false;
        }
    }

    // ----- Helpers -----
    today() {
        return new Date().toISOString().substring(0, 10);
    }
    todayPlus(days) {
        const d = new Date();
        d.setDate(d.getDate() + days);
        return d.toISOString().substring(0, 10);
    }
    reduceError(error) {
        // AuraHandledException puts the cleaned text in body.message
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'An unknown error occurred.';
    }
}