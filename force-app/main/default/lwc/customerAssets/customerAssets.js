import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyAssets from '@salesforce/apex/CommunityPortalController.getMyAssets';

const COLUMNS = [
    { label: 'Asset Name',     fieldName: 'name',         type: 'text',     sortable: true },
    { label: 'Product',        fieldName: 'productName',  type: 'text' },
    { label: 'Status',         fieldName: 'status',       type: 'text',
      cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'Purchase Date',  fieldName: 'purchaseDate', type: 'date-local',
      typeAttributes: { month: '2-digit', day: '2-digit', year: 'numeric' } },
    { label: 'Quantity',       fieldName: 'quantity',     type: 'number' },
    { label: 'Price',          fieldName: 'price',        type: 'currency',
      typeAttributes: { currencyCode: 'USD' } },
    { label: 'Warranty',       fieldName: 'warrantyLabel', type: 'text',
      cellAttributes: { class: { fieldName: 'warrantyClass' },
                        iconName: { fieldName: 'warrantyIcon' },
                        iconPosition: 'left' } }
];

export default class CustomerAssets extends LightningElement {
    @track assets = [];
    @track error;
    isLoading = true;
    columns = COLUMNS;
    wiredAssetsResult;

    @wire(getMyAssets)
    wiredAssets(result) {
        this.wiredAssetsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.assets = result.data.map(a => this.decorateAsset(a));
            this.error = undefined;
        } else if (result.error) {
            this.assets = [];
            this.error = this.reduceError(result.error);
        }
    }

    // Add display-only fields for color-coded cells
    decorateAsset(a) {
        return {
            ...a,
            statusClass: this.statusClass(a.status),
            warrantyLabel: a.hasActiveWarranty ? 'Active' : 'Not registered',
            warrantyIcon:  a.hasActiveWarranty ? 'utility:success' : 'utility:warning',
            warrantyClass: a.hasActiveWarranty
                ? 'slds-text-color_success'
                : 'slds-text-color_weak'
        };
    }

    statusClass(status) {
        switch (status) {
            case 'Installed': return 'slds-text-color_success';
            case 'Purchased': return 'slds-text-color_default';
            case 'Returned':  return 'slds-text-color_destructive';
            default:          return '';
        }
    }

    get isEmpty() {
        return !this.isLoading && !this.error && this.assets.length === 0;
    }
    get hasData() {
        return !this.isLoading && !this.error && this.assets.length > 0;
    }
    get assetCount() {
        return this.assets.length;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredAssetsResult)
            .finally(() => { this.isLoading = false; });
    }

    handleRowAction(event) {
        // Reserved for future "View details" navigation
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}