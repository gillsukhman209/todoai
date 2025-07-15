# TodoAI - Smart Task Management

A beautiful SwiftUI todo app with natural language processing powered by OpenAI. Create tasks using natural, human-friendly commands that are automatically parsed into structured, scheduled todos.

## ✨ Features

### 🧠 Natural Language Task Creation

Create tasks using natural language commands like:

- **"call dad at 6am"** → One-time task scheduled for 6 AM
- **"pay PGE every Friday at 10am"** → Weekly recurring task
- **"workout every Mon, Wed, Fri at 7pm"** → Specific weekday schedule
- **"stretch every 2 hours from 8am to 8pm"** → Custom interval with time range
- **"drink water every 30 minutes from 9am to 5pm"** → Frequent reminders during work hours
- **"submit report monthly on the 1st at 9am"** → Monthly recurring tasks

### 📱 Modern SwiftUI Interface

- Beautiful gradient backgrounds with glass morphism effects
- Smooth animations and transitions
- Dark mode optimized design
- Keyboard navigation support
- Floating sidebar with task organization

### 🔄 Advanced Scheduling

- **Daily, weekly, monthly, yearly recurrence**
- **Custom intervals** (every X hours/minutes)
- **Specific weekdays** (Mon, Wed, Fri)
- **Multiple times per day** (10am and 6pm)
- **Time ranges** (from 9am to 5pm)
- **Monthly day targeting** (1st, 15th, last day)

## 🚀 Getting Started

### 1. Set Up OpenAI API Key

1. Open the app and click the **Settings** button in the sidebar
2. Go to [platform.openai.com](https://platform.openai.com)
3. Sign in or create an account
4. Navigate to the **API Keys** section
5. Create a new secret key
6. Copy and paste it into the app

⚠️ **Important**: Your API key is stored locally in your device's UserDefaults and is never shared or transmitted anywhere except directly to OpenAI's servers for processing your requests.

### 2. Create Your First Smart Task

1. Click the **🧠 AI** button in the toolbar (⌘+I)
2. Toggle **AI Mode** on
3. Type a natural language command like:
   ```
   remind me to take vitamins every morning at 8am
   ```
4. Review the parsed preview
5. Click **Create Task**

### 3. Create Any Task

All tasks now go through AI processing for smart scheduling. Even simple tasks like:

```
Buy groceries
```

Will be processed by AI to check for any scheduling opportunities.

## 🎯 Natural Language Examples

### One-Time Tasks

```
call mom at 7pm
submit project proposal by Friday
doctor appointment tomorrow at 2:30pm
```

### Daily Tasks

```
journal every night at 9pm
take vitamins every morning
check emails at 9am and 5pm daily
```

### Weekly Tasks

```
grocery shopping every Sunday at 10am
workout every Mon, Wed, Fri at 6pm
team meeting every Tuesday at 2pm
```

### Custom Intervals

```
drink water every 30 minutes from 9am to 5pm
stretch every 2 hours during work
backup files every 3 days
```

### Monthly Tasks

```
pay rent on the 1st at 9am every month
review budget monthly on the 15th
```

## ⌨️ Keyboard Shortcuts

- **⌘+I** - Open AI smart input
- **⌘+N** - Open AI smart input (same as ⌘+I)
- **⌘+B** - Toggle sidebar
- **↑/↓** - Navigate tasks
- **E** - Edit focused task
- **Delete** - Remove focused task

## 🏗️ Architecture

### Models

- **`Todo`** - Enhanced with scheduling capabilities
- **`RecurrenceConfig`** - Handles all types of recurrence patterns
- **`TimeRange`** - Manages time-based constraints
- **`ParsedTaskData`** - Structures AI parsing results

### Services

- **`OpenAIService`** - Handles natural language parsing
- **`TaskCreationViewModel`** - Manages task creation logic

### Views

- **`NaturalLanguageInputView`** - Smart input interface
- **`NaturalLanguageInputOverlay`** - Modal presentation
- **`APIKeySetupView`** - OpenAI configuration

## 🔮 Future Enhancements

The system is designed to be extensible for future features:

- **Smart notifications** based on scheduling
- **Task dependencies** and workflows
- **Location-based reminders**
- **Integration with calendar apps**
- **Voice input support**
- **Multi-language support**
- **Collaborative task sharing**

## 🛠️ Development

Built with:

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Core Data successor for persistence
- **OpenAI API** - GPT-4 for natural language processing
- **UserNotifications** - Smart reminder system
- **Combine** - Reactive programming

## 🔐 Security

### API Key Handling

- **Local Storage**: Your OpenAI API key is stored securely in your device's UserDefaults
- **No Transmission**: The key is never sent to any server other than OpenAI's official API
- **No Logging**: API keys are never logged in plain text (only prefixes for debugging)
- **Git Safe**: The codebase contains no hardcoded API keys - all keys are user-provided

### Best Practices

1. **Never share your API key** - It's unique to your OpenAI account
2. **Monitor usage** - Check your OpenAI dashboard for API usage
3. **Rotate keys regularly** - Generate new keys periodically for security
4. **Use spending limits** - Set usage limits in your OpenAI account

### What's Protected

- ✅ API keys stored locally only
- ✅ No sensitive data in version control
- ✅ Proper error handling for missing keys
- ✅ Secure UserDefaults storage
- ✅ No hardcoded credentials in source code

## 🔮 Future Enhancements

The system is designed to be extensible for future features:

- **Smart notifications** based on scheduling
- **Task dependencies** and workflows
- **Location-based reminders**
- **Integration with calendar apps**
- **Voice input support**
- **Multi-language support**
- **Collaborative task sharing**

## 📄 License

This project is built as a demonstration of modern SwiftUI development with AI integration.

---

**Happy task managing! 🎉**
