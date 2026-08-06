package com.smartfund.pages;

import org.openqa.selenium.By;

public class AppPages {

    public static class SplashScreenPage extends BasePage {
        private final By logo = By.id("splash_logo");
        private final By getStartedBtn = By.id("btn_get_started");

        public boolean isLogoVisible() { return isDisplayed(logo); }
        public void clickGetStarted() { click(getStartedBtn); }
    }

    public static class LoginPage extends BasePage {
        private final By emailInput = By.id("input_email");
        private final By passwordInput = By.id("input_password");
        private final By loginBtn = By.id("btn_login");
        private final By registerLink = By.id("link_register");
        private final By errorMsg = By.id("text_error");

        public void login(String email, String password) {
            sendKeys(emailInput, email);
            sendKeys(passwordInput, password);
            click(loginBtn);
        }

        public void clickRegister() { click(registerLink); }
        public String getErrorMessage() { return getText(errorMsg); }
    }

    public static class RegisterPage extends BasePage {
        private final By nameInput = By.id("input_name");
        private final By emailInput = By.id("input_email");
        private final By passwordInput = By.id("input_password");
        private final By confirmPasswordInput = By.id("input_confirm_password");
        private final By registerBtn = By.id("btn_register");

        public void register(String name, String email, String password) {
            sendKeys(nameInput, name);
            sendKeys(emailInput, email);
            sendKeys(passwordInput, password);
            sendKeys(confirmPasswordInput, password);
            click(registerBtn);
        }
    }

    public static class DashboardPage extends BasePage {
        private final By totalBalanceText = By.id("text_total_balance");
        private final By addExpenseBtn = By.id("btn_add_expense");
        private final By analyticsTab = By.id("tab_analytics");
        private final By budgetTab = By.id("tab_budget");
        private final By goalsTab = By.id("tab_goals");

        public boolean isDashboardLoaded() { return isDisplayed(totalBalanceText); }
        public void clickAddExpense() { click(addExpenseBtn); }
        public void navigateToAnalytics() { click(analyticsTab); }
    }

    public static class AddExpensePage extends BasePage {
        private final By amountInput = By.id("input_amount");
        private final By categoryDropdown = By.id("dropdown_category");
        private final By noteInput = By.id("input_note");
        private final By saveBtn = By.id("btn_save_expense");

        public void addExpense(String amount, String category, String note) {
            sendKeys(amountInput, amount);
            sendKeys(noteInput, note);
            click(saveBtn);
        }
    }

    public static class ExpenseListPage extends BasePage {
        private final By searchInput = By.id("input_search");
        private final By expenseItems = By.id("list_expense_items");

        public void searchExpense(String query) { sendKeys(searchInput, query); }
        public boolean hasItems() { return isDisplayed(expenseItems); }
    }

    public static class AnalyticsPage extends BasePage {
        private final By chartContainer = By.id("chart_container");
        public boolean isChartVisible() { return isDisplayed(chartContainer); }
    }

    public static class BudgetPage extends BasePage {
        private final By setBudgetBtn = By.id("btn_set_budget");
        public boolean isBudgetVisible() { return isDisplayed(setBudgetBtn); }
    }

    public static class GoalsPage extends BasePage {
        private final By addGoalBtn = By.id("btn_add_goal");
        public boolean isGoalsPageLoaded() { return isDisplayed(addGoalBtn); }
    }

    public static class GroupSplitPage extends BasePage {
        private final By createGroupBtn = By.id("btn_create_group");
        public boolean isGroupSplitLoaded() { return isDisplayed(createGroupBtn); }
    }

    public static class ChatbotPage extends BasePage {
        private final By chatInput = By.id("input_chat");
        private final By sendBtn = By.id("btn_send");

        public void sendMessage(String message) {
            sendKeys(chatInput, message);
            click(sendBtn);
        }
    }

    public static class SettingsPage extends BasePage {
        private final By logoutBtn = By.id("btn_logout");
        private final By darkModeToggle = By.id("toggle_dark_mode");

        public void logout() { click(logoutBtn); }
        public void toggleDarkMode() { click(darkModeToggle); }
    }
}
