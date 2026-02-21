# Utils Module Integration Test

## Manual Testing Instructions

Since we cannot run Lua directly in this environment, here are manual testing steps to verify the Utils module loads correctly in-game:

### Prerequisites
1. World of Warcraft client (WotLK 3.4.3)
2. KeywordMonitor addon installed

### Test Procedure

#### Test 1: Module Loading
1. Start WoW and log into a character
2. Open the chat window
3. Type: `/dump KeywordMonitor`
4. **Expected Result:** Should show a table with the KeywordMonitor namespace

#### Test 2: Utils Namespace
1. Type: `/dump KeywordMonitor.Utils`
2. **Expected Result:** Should show a table with the Utils module

#### Test 3: Module Loaded Flag
1. Type: `/dump KeywordMonitor.Utils.Loaded`
2. **Expected Result:** Should return `true`

#### Test 4: Function Existence
Test each function individually:

```lua
/dump KeywordMonitor.Utils.CleanText
/dump KeywordMonitor.Utils.SplitString
/dump KeywordMonitor.Utils.CreateBD
/dump KeywordMonitor.Utils.CreateFS
/dump KeywordMonitor.Utils.CreateButton
/dump KeywordMonitor.Utils.CreateCheckBox
/dump KeywordMonitor.Utils.CreateEditBox
/dump KeywordMonitor.Utils.CreateCloseButton
/dump KeywordMonitor.Utils.CleanupUIElements
```

**Expected Result:** Each should return `function: 0x...` (a function reference)

#### Test 5: CleanText Function
1. Type: `/dump KeywordMonitor.Utils.CleanText("|cff00ff00Hello|r World!")`
2. **Expected Result:** Should return `"HELLOWORLD"`

#### Test 6: SplitString Function
1. Type: `/dump KeywordMonitor.Utils.SplitString("apple,banana,cherry", ",")`
2. **Expected Result:** Should return a table with 3 elements: `{"apple", "banana", "cherry"}`

#### Test 7: Check for Lua Errors
1. Open the game menu (ESC)
2. Go to Interface → AddOns
3. Enable "Display Lua Errors" if not already enabled
4. Reload UI: `/reload`
5. **Expected Result:** No Lua errors should appear

#### Test 8: Addon Loading Order
1. Type: `/dump GetAddOnInfo("KeywordMonitor")`
2. **Expected Result:** Should show addon is loaded
3. Check the loading order in the .toc file matches the expected order

### Verification Checklist

- [ ] KeywordMonitor namespace exists
- [ ] KeywordMonitor.Utils namespace exists
- [ ] KeywordMonitor.Utils.Loaded is true
- [ ] All 9 functions are accessible
- [ ] CleanText function works correctly
- [ ] SplitString function works correctly
- [ ] No Lua errors on addon load
- [ ] No Lua errors on UI reload

### Troubleshooting

If any test fails:

1. **Module not found:**
   - Check that `Modules\Utils.lua` is listed in `KeywordMonitor.toc`
   - Verify the file path is correct (backslashes for Windows)
   - Reload UI: `/reload`

2. **Functions return nil:**
   - Check for syntax errors in Utils.lua
   - Enable Lua error display
   - Check the error log

3. **Lua errors on load:**
   - Read the error message carefully
   - Check line numbers in Utils.lua
   - Verify all `end` statements match function definitions

### Success Criteria

All tests must pass for the Utils module to be considered successfully loaded and ready for use by other modules.

---

## Automated Verification (Code Review)

Since we cannot run Lua in this environment, the following automated checks have been performed:

### ✅ Static Analysis Results

1. **File Structure:** Valid
   - File exists at correct location
   - Proper header comments
   - Clear section organization

2. **Function Count:** 9/9 functions defined
   - All required functions present
   - All functions in KM.Utils namespace

3. **Syntax Check:** Valid
   - All functions have matching `end` statements
   - No obvious syntax errors
   - Proper Lua structure

4. **Module Flag:** Set
   - `KM.Utils.Loaded = true` present at line 237

5. **TOC Integration:** Valid
   - Utils.lua listed first in module loading order
   - Correct path in .toc file

### Conclusion

Based on static analysis, the Utils module is correctly structured and should load without errors. Manual in-game testing is recommended to confirm runtime behavior.
