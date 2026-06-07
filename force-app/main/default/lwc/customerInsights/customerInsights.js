import { LightningElement } from 'lwc';
import getCustomerInsights from '@salesforce/apex/CustomerInsightsController.getCustomerInsights';
import getRecommendation from '@salesforce/apex/CustomerInsightsController.getRecommendation';

export default class CustomerInsights extends LightningElement {
    customerId = '';
    customer;
    recommendation;
    error;
    isLoading = false;
    isRecommendationLoading = false;
    showActivities = false;

    //to get the customer(Contact id) from agent
    handleCustomerIdChange(event) {
        this.customerId = event.target.value;
    }

    //to get the customer insights data
    async loadCustomerInsights() {
        this.error = null;
        this.customer = null;
        this.recommendation = null;

        if (!this.customerId) {
            this.error = 'Please enter a Customer ID.';
            return;
        }

        this.isLoading = true;

        try {
            this.customer = await getCustomerInsights({
                customerId: this.customerId
            });
        } catch (error) {
            this.error = error.body?.message || 'Unable to load customer insights.';
        } finally {
            this.isLoading = false;
        }
    }
    // to get recommendation based on the engagement
    async getAIRecommendation() {
        this.error = null;
        this.recommendation = null;

        if (!this.customer) {
            this.error = 'Please load a customer before getting recommendation.';
            return;
        }

        this.isRecommendationLoading = true;

        try {
            this.recommendation = await getRecommendation({
                engagementScore: this.customer.engagementScore,
                intentLevel: this.customer.intentLevel,
                productInterest: this.customer.productInterest
            });
        } catch (error) {
            this.error = error.body?.message || 'Unable to get recommendation.';
        } finally {
            this.isRecommendationLoading = false;
        }
    }
    //expand and collapse button
    toggleActivities() {
        this.showActivities = !this.showActivities;
    }
    //label for expand and collapse button based on user onclick
    get activityButtonLabel() {
        return this.showActivities ? 'Collapse Activity' : 'Expand Activity';
    }

    //to get the activities of the customer(we are considering CRM Tasks and events also for this along with mock data from apex on engagement data)
    get hasActivities() {
        return this.customer &&
            this.customer.recentActivities &&
            this.customer.recentActivities.length > 0;
    }
    // to display the intent text
    get intentClass() {
        if (!this.customer) {
            return '';
        }

        if (this.customer.intentLevel === 'High') {
            return 'intent-high';
        }

        if (this.customer.intentLevel === 'Medium') {
            return 'intent-medium';
        }

        return 'intent-low';
    }
}
