# Worker Dashboard & User Feedback Implementation Plan

## Approved Plan Steps (Completed: Mark as you go)

### Step 1: Update main.dart - Add routes [✅]
### Step 2: Enhance worker_profile.dart - Full Worker Dashboard [✅]

### Step 3: Add feedback to tecil.dart - User Review Form [✅]

### Step 2: Enhance worker_profile.dart - Full Worker Dashboard [ ]
- Add routes: '/user_home' → UserDashboardScreen, '/worker_home' → WorkerProfileScreen
- Update login.dart navigation to use named routes.

### Step 2: Enhance worker_profile.dart - Full Worker Dashboard [ ]
- Add read-only summary section (photo, skills chips, charges, avg rating).
- Add toggle Edit/View mode.
- Display own ratings/reviews list.

### Step 3: Add feedback to technician_detail.dart - User Review Form [ ]
- Add bottom section: Star rating picker (1-5), comment textfield, submit.
- On submit: Append rating num to worker['ratings'] array in Firestore.
- Show recent reviews (fetch worker ratings, mock user names).

### Step 4: Minor polish user_home.dart [ ]
- Ensure skills/charges display consistently.
- Add loading/error handling if needed.

### Step 5: Test & Verify [ ]
- Run `flutter pub get`
- `flutter run`
- Test: Login as worker → see/edit profile; User → view workers → submit feedback → verify Firestore.

### Step 6: Update TODO.md [Auto]
- Mark completed.

**Progress: 0/6**  
**Next: Start with Step 1**
