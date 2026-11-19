#!/usr/bin/env python3
"""Generate lib/l10n/ui_text.dart from the translation tables below.

This is a development tool.  The generated Dart file is committed and is the
runtime source of truth.  Run this script after editing a translation.
"""

from __future__ import annotations

import json
from pathlib import Path

from word_translations import TECHNICAL, WORDS

ROOT = Path(__file__).resolve().parents[1]

# English source -> (Amharic, Afaan Oromoo)
UI: dict[str, tuple[str, str]] = {
    "Search records": ("መዝገቦችን ፈልግ", "Galmee barbaadi"),
    "Refresh": ("አድስ", "Haaromsi"),
    "Export CSV": ("CSV አውጣ", "CSV baasi"),
    "Export PDF": ("PDF አውጣ", "PDF baasi"),
    "Add": ("ጨምር", "Dabalii"),
    "Cash balance": ("የጥሬ ገንዘብ ቀሪ ሂሳብ", "Haftee maallaqa harkaa"),
    "Today's sales": ("የዛሬ ሽያጭ", "Gurgurtaa har'aa"),
    "Low stock": ("ያነሰ ክምችት", "Kuusaa xiqqaa"),
    "Overdue": ("ያለፈ ጊዜ", "Yeroon darbe"),
    "Rent due": ("የሚከፈል ኪራይ", "Kiraa kaffalamuu qabu"),
    "Staff present": ("የተገኙ ሰራተኞች", "Hojjettoota argaman"),
    "No records yet": ("እስካሁን መዝገብ የለም", "Galmeen ammatti hin jiru"),
    "Branches": ("ቅርንጫፎች", "Dameewwan"),
    "Users & roles": ("ተጠቃሚዎች እና ሚናዎች", "Fayyadamtoota fi gaheewwan"),
    "Assign branch, role and active status": (
        "ቅርንጫፍ፣ ሚና እና ንቁ ሁኔታ ይመድቡ",
        "Damee, gahee fi haala socho'aa ramadi",
    ),
    "Try again": ("እንደገና ሞክር", "Irra deebi'ii yaali"),
    "Account deactivated. Contact an administrator.": (
        "መለያው ተሰናክሏል። እባክዎ አስተዳዳሪን ያግኙ።",
        "Herregni sun dhaabbateera. Maaloo bulchaa qunnamaa.",
    ),
    "Reset language": ("ቋንቋ ዳግም አስጀምር", "Afaan irra deebi'i"),
    "Approvals": ("ማጽደቆች", "Mirkaneessaa"),
    "Approve": ("አጽድቅ", "Mirkaneessi"),
    "Reject": ("ውድቅ አድርግ", "Didi"),
    "Pay payable": ("የሚከፈል ክፈል", "Kaffaltii kaffali"),
    "Cash & expenses": ("ገንዘብ እና ወጪዎች", "Maallaqa fi baasii"),
    "Create payable": ("የሚከፈል ፍጠር", "Kaffaltii uumi"),
    "Cash account": ("የገንዘብ ሂሳብ", "Herrega maallaqaa"),
    "Amount": ("መጠን", "Hamma"),
    "Method": ("ዘዴ", "Mala"),
    "Reference": ("ማጣቀሻ", "Wabii"),
    "Approve write-off?": ("ስረዛን አጽድቅ?", "Haqaa mirkaneessaa?"),
    "The database trigger will reduce the receivable balance.": (
        "የውሂብ ጎታ ተንቀሳቃሽ የሚቀበሉትን ቀሪ ሂሳብ ይቀንሳል።",
        "Kakaasaa daataa haftee fudhatamuu hir'isa.",
    ),
    "Credit & debit control": ("ብድር እና ዴቢት ቁጥጥር", "To'annoo liqii fi deebitii"),
    "Receive payment": ("ክፍያ ተቀበል", "Kaffaltii fudhadhu"),
    "Pay supplier": ("አቅራቢን ክፈል", "Dhiyeessaa kaffali"),
    "Approve write-off": ("ስረዛ አጽድቅ", "Haqaa mirkaneessi"),
    "My account": ("የእኔ መለያ", "Herrega koo"),
    "Customer profile": ("የደንበኛ መገለጫ", "Profaayilii maamilaa"),
    "Cake orders": ("የኬክ ትዕዛዞች", "Ajajoota keekii"),
    "No cake orders yet.": ("እስካሁን የኬክ ትዕዛዞች የሉም።", "Ajajoota keekii hin jiran."),
    "Credit balance": ("የብድር ቀሪ ሂሳብ", "Haftee liqii"),
    "No outstanding credit.": ("ያልተከፈለ ብድር የለም።", "Liqii hafe hin jiru."),
    "Receiving store": ("መቀበያ መጋዘን", "Kuusaa fudhatamaa"),
    "Approve stock count?": ("የክምችት ቆጠራን አጽድቅ?", "Lakkoofsa kuusaa mirkaneessaa?"),
    "The database trigger will post counted variances to stock.": (
        "የውሂብ ጎታ ተንቀሳቃሽ የተቆጠሩ ልዩነቶችን ወደ ክምችት ይመዘግባል።",
        "Kakaasaa daataa garaagarummaa lakkaa'ame gara kuusaatti galmeessa.",
    ),
    "Inventory & purchasing": ("ክምችት እና ግዢ", "Kuusaa fi bittaa"),
    "Receive goods": ("ዕቃ ተቀበል", "Meeshaa fudhadhu"),
    "Approve count": ("ቆጠራ አጽድቅ", "Lakkoofsa mirkaneessi"),
    "Notifications": ("ማሳወቂያዎች", "Beeksisota"),
    "Generate alerts": ("ማንቂያዎችን ፍጠር", "Akeekkachiisa uumi"),
    "Reload": ("እንደገና ጫን", "Irra deebi'ii fe'i"),
    "No notifications yet. Generate alerts to refresh.": (
        "እስካሁን ማሳወቂያዎች የሉም። ለማደስ ማንቂያዎችን ፍጠር።",
        "Beeksisota hin jiran. Haaromsuuf akeekkachiisa uumi.",
    ),
    "Mark read": ("እንደተነበበ ምልክት አድርግ", "Dubbatame godhi"),
    "Generate payslips?": ("የደመወዝ ደረሰኞችን ፍጠር?", "Nagahee mindaa uumaa?"),
    "The database will calculate gross pay, tax, pension, advances and net pay.": (
        "የውሂብ ጎታ ጠቅላላ ክፍያ፣ ታክስ፣ ጡረታ፣ ቅድሚያ ክፍያዎች እና የተጣራ ክፍያን ያሰላል።",
        "Daataan mindaa waliigalaa, taaksii, soorama, dursee kaffaltii fi mindaa qulqulluu shallaga.",
    ),
    "This updates the payroll run and lets the database apply its totals.": (
        "ይህ የደመወዝ ክፍያ ሩጫን ያዘምናል እና የውሂብ ጎታው ድምሮቹን እንዲተገበር ያደርጋል።",
        "Kun fiigii kaffaltii mindaa haaromsa, daataan waliigala isaa hojiirra oolcha.",
    ),
    "Payslip": ("የደመወዝ ደረሰኝ", "Nagahee mindaa"),
    "Payroll": ("የደመወዝ ክፍያ", "Kaffaltii mindaa"),
    "Generate payslips": ("የደመወዝ ደረሰኞችን ፍጠር", "Nagahee mindaa uumi"),
    "Approve run": ("ሩጫ አጽድቅ", "Fiigii mirkaneessi"),
    "Mark paid": ("እንደተከፈለ ምልክት አድርግ", "Kaffalame godhi"),
    "Payslip PDF": ("የደመወዝ ደረሰኝ PDF", "Nagahee mindaa PDF"),
    "People & HR": ("ሰው ኃይል እና HR", "Hojjettoota fi HR"),
    "Approve leave": ("ፈቃድ አጽድቅ", "Boqonnaa mirkaneessi"),
    "Reject leave": ("ፈቃድ ውድቅ አድርግ", "Boqonnaa didi"),
    "Complete sale": ("ሽያጭ ጨርስ", "Gurgurtaa xumuri"),
    "Completing…": ("በመጨረስ ላይ…", "Xumuraa jira…"),
    "Sales receipt": ("የሽያጭ ደረሰኝ", "Nagahee gurgurtaa"),
    "Sale completed": ("ሽያጭ ተጠናቅቋል", "Gurgurtaan xumurame"),
    "Price is 0": ("ዋጋ 0 ነው", "Gatiin 0 dha"),
    "A product in this sale has a price of 0. Continue?": (
        "በዚህ ሽያጭ ውስጥ ያለ ምርት ዋጋው 0 ነው። ይቀጥሉ?",
        "Oomishni gurgurtaa kana keessa jiru gatiin isaa 0 dha. Itti fufuu?",
    ),
    "Continue": ("ቀጥል", "Itti fufi"),
    "Receipt PDF": ("ደረሰኝ PDF", "Nagahee PDF"),
    "Point of sale": ("የሽያጭ ነጥብ", "Iddoo gurgurtaa"),
    "Clear cart": ("ጋሪ አጽዳ", "Gaarii haqi"),
    "Cart": ("ጋሪ", "Gaarii"),
    "Products": ("ምርቶች", "Oomishaalee"),
    "Current sale": ("የአሁኑ ሽያጭ", "Gurgurtaa ammaa"),
    "Show password": ("የይለፍ ቃል አሳይ", "Jecha darbii agarsiisi"),
    "Hide password": ("የይለፍ ቃል ደብቅ", "Jecha darbii dhoksi"),
    "Decrease quantity": ("ብዛት ቀንስ", "Baay'ina hir'isi"),
    "Increase quantity": ("ብዛት ጨምር", "Baay'ina dabali"),
    "Search products": ("ምርቶችን ፈልግ", "Oomishaalee barbaadi"),
    "No active products. Add products in Production.": (
        "ንቁ ምርቶች የሉም። በምርት ክፍል ውስጥ ምርቶችን ያክሉ።",
        "Oomishaalee socho'aa hin jiran. Oomishaalee kutaa Oomishaatti dabali.",
    ),
    "Tap a product to add it to the sale.": (
        "ሽያጩ ላይ ለመጨመር ምርትን ይንኩ።",
        "Gurgurtaa keessatti dabaluuf oomisha tuqi.",
    ),
    "Add at least one product to the sale": (
        "ቢያንስ አንድ ምርት ወደ ሽያጩ ያክሉ",
        "Yoo xiqqaate oomisha tokko gara gurgurtaatti dabali",
    ),
    "Enter a quantity greater than zero.": (
        "ከዜሮ በላይ የሆነ ብዛት ያስገቡ።",
        "Baay'ina zeeroo ol ta'e galchi.",
    ),
    "Create a store before selling": (
        "ከመሸጥዎ በፊት መጋዘን ይፍጠሩ",
        "Osoo hin gurgurin dura kuusaa uumi",
    ),
    "Create a cash account before selling": (
        "ከመሸጥዎ በፊት የገንዘብ ሂሳብ ይፍጠሩ",
        "Osoo hin gurgurin dura herrega maallaqaa uumi",
    ),
    "Choose a customer for a credit sale.": (
        "ለብድር ሽያጭ ደንበኛ ይምረጡ።",
        "Gurgurtaa liqii maamila filadhu.",
    ),
    "Payment does not cover the total.": (
        "ክፍያው ጠቅላላውን አይሸፍንም።",
        "Kaffaltiin ida'ama hin guutu.",
    ),
    "Pick a cash account for this payment": (
        "ለዚህ ክፍያ የገንዘብ ሂሳብ ይምረጡ",
        "Kaffaltii kanaaf herrega maallaqaa filadhu",
    ),
    "Pick a customer for credit sales": (
        "ለብድር ሽያጭ ደንበኛ ይምረጡ",
        "Gurgurtaa liqii maamila filadhu",
    ),
    "Paid amount cannot exceed the sale total.": (
        "የተከፈለው መጠን ከሽያጭ ድምር መብለጥ አይችልም።",
        "Hamma kaffalame ida'ama gurgurtaa caaluu hin danda'u.",
    ),
    "Customer": ("ደንበኛ", "Maamila"),
    "Walk-in": ("የተራ ደንበኛ", "Maamila kallattii"),
    "Walk-in customer": ("የተራ ደንበኛ", "Maamila kallattii"),
    "Store": ("መጋዘን", "Kuusaa"),
    "Payment method": ("የክፍያ ዘዴ", "Mala kaffaltii"),
    "Cash": ("ጥሬ ገንዘብ", "Maallaqa harkaa"),
    "Bank transfer": ("የባንክ ማስተላለፍ", "Dabarsa baankii"),
    "Mobile money": ("የሞባይል ገንዘብ", "Maallaqa moobaayilii"),
    "Card": ("ካርድ", "Kaardii"),
    "Credit": ("ብድር", "Liqii"),
    "Discount (ETB)": ("ቅናሽ (ETB)", "Hir'isa (ETB)"),
    "Subtotal": ("ንዑስ ድምር", "Ida'ama xiqqaa"),
    "Discount": ("ቅናሽ", "Hir'isa"),
    "Tax": ("ታክስ", "Taaksii"),
    "Amount paid": ("የተከፈለ መጠን", "Hamma kaffalame"),
    "Notes": ("ማስታወሻዎች", "Yaadannoo"),
    "Complete production batch?": ("የምርት ስብስብ ጨርስ?", "Baachii oomishaa xumuraa?"),
    "The database trigger will consume ingredients and add finished stock.": (
        "የውሂብ ጎታ ተንቀሳቃሽ ግብዓቶችን ይጠቀማል እና የተጠናቀቀ ክምችት ይጨምራል።",
        "Kakaasaa daataa qalqalloo fayyadama, kuusaa xumurame dabala.",
    ),
    "Production & catalog": ("ምርት እና ካታሎግ", "Oomisha fi kaataloogii"),
    "Complete batch": ("ስብስብ ጨርስ", "Baachii xumuri"),
    "Advance status": ("ሁኔታ አራምድ", "Haala dursi"),
    "Generate rent invoices?": ("የኪራይ ደረሰኞችን ፍጠር?", "Nagahee kiraa uumaa?"),
    "The database will create invoices for active leases for today.": (
        "የውሂብ ጎታ ለዛሬ ንቁ ውሎች ደረሰኞችን ይፈጥራል።",
        "Daataan waliigaltee socho'aa har'aaf nagahee uuma.",
    ),
    "Rentals": ("ኪራይ", "Kiraa"),
    "Record rent": ("ኪራይ መዝግብ", "Kiraa galmeessi"),
    "Reports & analytics": ("ሪፖርቶች እና ትንታኔ", "Gabaasa fi xiinxala"),
    "Report view": ("የሪፖርት እይታ", "Ilaalcha gabaasaa"),
    "Refresh": ("አድስ", "Haaromsi"),
    "Void this sale?": ("ይህን ሽያጭ ሰርዝ?", "Gurgurtaa kana haqi?"),
    "The database restores stock, cash and credit for this sale. This cannot be undone.": (
        "የውሂብ ጎታ ለዚህ ሽያጭ ክምችት፣ ገንዘብ እና ብድርን ይመልሳል። ይህ ሊቀለበስ አይችልም።",
        "Daataan kuusaa, maallaqa fi liqii gurgurtaa kanaaf deebisa. Kun hin duubatti deebi'u.",
    ),
    "Sales & returns": ("ሽያጭ እና መመለሻ", "Gurgurtaa fi deebii"),
    "New sale": ("አዲስ ሽያጭ", "Gurgurtaa haaraa"),
    "Print receipt": ("ደረሰኝ አትም", "Nagahee maxxansi"),
    "Record return": ("መመለሻ መዝግብ", "Deebii galmeessi"),
    "Void sale": ("ሽያጭ ሰርዝ", "Gurgurtaa haqi"),
    "Close today": ("ዛሬን ዝጋ", "Har'a cufi"),
    "Reason": ("ምክንያት", "Sababa"),
    "Return qty": ("የመመለሻ ብዛት", "Baay'ina deebii"),
    "Close business day": ("የንግድ ቀን ዝጋ", "Guyyaa daldalaa cufi"),
    "Counted cash": ("የተቆጠረ ገንዘብ", "Maallaqa lakkaa'ame"),
    "Table": ("ሠንጠረዥ", "Gabatee"),
    "User ID": ("የተጠቃሚ ID", "ID fayyadamaa"),
    "Action": ("እርምጃ", "Gocha"),
    "No audit entries match these filters.": (
        "ከእነዚህ ማጣሪያዎች ጋር የሚዛመድ የኦዲት መዝገብ የለም።",
        "Galmeen oditii filtaroota kanaan hin walsu.",
    ),
    "Report": ("ሪፖርት", "Gabaasa"),
    "This report returned no rows.": (
        "ይህ ሪፖርት ምንም ረድፎች አልመለሰም።",
        "Gabaasni kun tarree hin deebisne.",
    ),
    "Stores & cash accounts": ("መጋዘኖች እና የገንዘብ ሂሳቦች", "Kuusaa fi herrega maallaqaa"),
    "Code": ("ኮድ", "Koodii"),
    "Symbol": ("ምልክት", "Mallattoo"),
    "Tax rates": ("የታክስ መጠኖች", "Safartuu taaksii"),
    "Getting help": ("እርዳታ ማግኘት", "Gargaarsa argachuu"),
    "Before you report a problem": ("ችግር ከመግለጽዎ በፊት", "Rakkoo gabaasuu kee dura"),
    "Support information to include": (
        "የሚያካትቱት የድጋፍ መረጃ",
        "Odeeffannoo deeggarsaa dabaluu qabdu",
    ),
    "What we store": ("ምን እናከማቻለን", "Maal kuusna"),
    "Who can see it": ("ማን ማየት ይችላል", "Eenyu ilaaluu danda'a"),
    "Device storage": ("የመሣሪያ ማከማቻ", "Kuusaa meeshaa"),
    "Your choices": ("ምርጫዎችዎ", "Filannoo kee"),
    "Name, slogan, currency, tax and default language": (
        "ስም፣ መፈክር, ገንዘብ, ታክስ እና ነባሪ ቋንቋ",
        "Maqaa, moojoo, maallaqa, taaksii fi afaan durtii",
    ),
    "Units, categories, departments, shifts and tax": (
        "ክፍሎች፣ ምድቦች፣ ክፍሎች፣ ፈረቃዎች እና ታክስ",
        "Yuunitiiwwan, ramaddiiwwan, dipartimentiiwwan, shiftaawwan fi taaksii",
    ),
    "Filter by table, user, action and date": (
        "በሠንጠረዥ፣ በተጠቃሚ፣ በእርምጃ እና በቀን አጣራ",
        "Gabatee, fayyadamaa, gocha fi guyyaan filtarii",
    ),
    "PDF with logo, CSV with every visible column": (
        "ከአርማ ጋር PDF፣ ከሁሉም የሚታዩ አምዶች ጋር CSV",
        "PDF mallattoo waliin, CSV kolommii mul'atu hunda waliin",
    ),
    "Storage": ("ማከማቻ", "Kuusaa"),
    "Branding": ("የምርት ስም", "Mallattoo"),
    "Creates stock, credit and rent alerts now.": (
        "አሁን የክምችት፣ የብድር እና የኪራይ ማንቂያዎችን ይፈጥራል።",
        "Amma akeekkachiisa kuusaa, liqii fi kiraa uuma.",
    ),
    "Official brand": ("ይፋዊ የምርት ስም", "Mallattoo idilee"),
    "Brand assets": ("የምርት ስም ንብረቶች", "Qabeenya mallattoo"),
    "No rows returned.": ("ምንም ረድፎች አልተመለሱም።", "Tarreen hin deebine."),
    "You do not have permission for this area.": (
        "ለዚህ አካባቢ ፈቃድ የለዎትም።",
        "Afaan kanaaf hayyama hin qabdu.",
    ),
    "You do not have permission to view this list.": (
        "ይህን ዝርዝር ለማየት ፈቃድ የለዎትም።",
        "Tarree kana ilaaluuf hayyama hin qabdu.",
    ),
    "Clear search": ("ፍለጋ አጽዳ", "Barbaadi haqi"),
    "CSV": ("CSV", "CSV"),
    "PDF": ("PDF", "PDF"),
    "Actions": ("እርምጃዎች", "Gochoota"),
    "Row actions": ("የረድፍ እርምጃዎች", "Gochoota tarree"),
    "Edit": ("አርትዕ", "Gulaali"),
    "Copy row": ("ረድፍ ቅዳ", "Tarree waraabi"),
    "Delete": ("አጥፋ", "Haqi"),
    "This permanently removes the record. Records referenced by transactions cannot be deleted.": (
        "ይህ መዝገቡን ለዘላለም ያስወግዳል። በግብይቶች የተጠቀሱ መዝገቦች ሊጠፉ አይችሉም።",
        "Kun galmee dhaabbii haqa. Galmeen transakshiniiwwaniin wabifame haqamuu hin danda'u.",
    ),
    "YYYY-MM-DD": ("YYYY-MM-DD", "YYYY-MM-DD"),
    "Afaan Oromoo": ("Afaan Oromoo", "Afaan Oromoo"),
    "Copy CSV": ("CSV ቅዳ", "CSV waraabi"),
    "Done": ("ተጠናቅቋል", "Xumurame"),
    "Required": ("ያስፈልጋል", "Barbaachisa"),
    "Enter a number": ("ቁጥር ያስገቡ", "Lakkoofsa galchi"),
    "Saving…": ("በማስቀመጥ ላይ…", "Olkaa'aa jira…"),
    "Save": ("አስቀምጥ", "Olkaa'i"),
    "Cancel": ("ሰርዝ", "Haqi"),
    "Yes": ("አዎ", "Eeyyee"),
    "No": ("አይ", "Lakki"),
    "Search": ("ፈልግ", "Barbaadi"),
    "New": ("አዲስ", "Haaraa"),
    "Create": ("ፍጠር", "Uumi"),
    "Close": ("ዝጋ", "Cufi"),
    "Add": ("ጨምር", "Dabali"),
    "Export": ("ላክ", "Al-ergi"),
    "Delete record?": ("መዝገብ አጥፋ?", "Galmee haqi?"),
    "Saved.": ("ተቀምጧል።", "Olkaa'ame."),
    "Deleted.": ("ጠፍቷል።", "Haqame."),
    "PDF exported.": ("PDF ተልኳል።", "PDF al-ergame."),
    "Pending approval": ("ማጽደቅ በመጠባበቅ ላይ", "Mirkaneessaa eegaa jira"),
    "Record payment": ("ክፍያ መዝግብ", "Kaffaltii galmeessi"),
    "Payable created from bill.": (
        "ከደረሰኝ የሚከፈል ተፈጥሯል።",
        "Kaffaltii nagahee irraa uumame.",
    ),
    "Payable payment recorded.": (
        "የሚከፈል ክፍያ ተመዝግቧል።",
        "Kaffaltiin kaffalame galmeeffame.",
    ),
    "Cash balance includes approved entries. Pending entries wait for approval.": (
        "የገንዘብ ቀሪ ሂሳብ የጸደቁ መዝገቦችን ያካትታል። በመጠባበቅ ላይ ያሉ መዝገቦች ማጽደቅ ይጠብቃሉ።",
        "Haftee maallaqaa galmee mirkanaa'an qofa dabalata. Galmeen eegaa jiru mirkaneessa eeggata.",
    ),
    "No products yet": ("እስካሁን ምርቶች የሉም።", "Oomishaaleen ammatti hin jiran."),
    "Generate invoices": ("ደረሰኞችን ፍጠር", "Resiitoota uumi"),
    "Build number": ("የግንባታ ቁጥር", "Lakkoofsa ijaarsaa"),
    "Commit": ("ኮሚት", "Galmeessa"),
    "Branch": ("ቅርንጫፍ", "Damee"),
    "Unknown": ("አይታወቅም", "Hin beekamu"),
    "Record overpayment?": (
        "ከመጠን በላይ ክፍያ መዝግብ?",
        "Kaffaltii hamma darbii galmeessi?",
    ),
    "This amount is more than the invoice balance. The extra will be recorded as an overpayment.": (
        "ይህ መጠን ከደረሰኝ ቀሪ ሂሳብ በላይ ነው። ትርፉ እንደ ከመጠን በላይ ክፍያ ይመዘገባል።",
        "Hammi kun haftee resiitii caala. Dambaliin akka kaffaltii hamma darbii galmeeffama.",
    ),
    "Record overpayment": (
        "ከመጠን በላይ ክፍያ መዝግብ",
        "Kaffaltii hamma darbii galmeessi",
    ),
    "Full report": ("ሙሉ ሪፖርት", "Gabaasa guutuu"),
    "Stock report": ("የክምችት ሪፖርት", "Gabaasa kuusaa"),
    "Sales report": ("የሽያጭ ሪፖርት", "Gabaasa gurgurtaa"),
    "Rent report": ("የኪራይ ሪፖርት", "Gabaasa kiraa"),
    "More report views": ("ተጨማሪ የሪፖርት እይታዎች", "Ilaalcha gabaasaa dabalataa"),
    "From": ("ከ", "Irraa"),
    "To": ("እስከ", "Hanga"),
    "Record sale": ("ሽያጭ መዝግብ", "Gurgurtaa galmeessi"),
    "Sale date": ("የሽያጭ ቀን", "Guyyaa gurgurtaa"),
    "Last sold at": ("የመጨረሻ ሽያጭ ሰዓት", "Yeroo gurgurtaa dhumaa"),
    "Add item to inventory": (
        "ዕቃን ወደ ክምችት ጨምር",
        "Meeshaa kuusaatti dabali",
    ),
    "Creates a linked inventory item and enables stock tracking.": (
        "ከዚህ ምርት ጋር የተያያዘ ዕቃ ይፈጥራል እና የክምችት ክትትልን ያነቃል።",
        "Meeshaa oomisha kanaan walqabate uuma, kuusaa hordofuu immoo ni dandeessisa.",
    ),
    "Next rent due": ("ቀጣይ የሚከፈል ኪራይ", "Kiraa kaffalamu itti aanu"),
    "Last payment": ("የመጨረሻ ክፍያ", "Kaffaltii dhumaa"),
    "Overdue rent": ("የተላለፈ ቀነ ገደብ ኪራይ", "Kiraa yeroo darbee"),
    "No rent due": ("የሚከፈል ኪራይ የለም", "Kiraan kaffalamu hin jiru"),
    "Report totals": ("የሪፖርት ጠቅላላ", "Waliigala gabaasaa"),
    "Total sales": ("ጠቅላላ ሽያጭ", "Gurgurtaa waliigalaa"),
    "Transactions": ("ግብይቶች", "Sochiiwwan"),
    "Stock value": ("የክምችት ዋጋ", "Gatii kuusaa"),
    "Rent collected": ("የተሰበሰበ ኪራይ", "Kiraa walitti qabame"),
    "Outstanding rent": ("ቀሪ ኪራይ", "Kiraa hafe"),
    "Cash in": ("የገቢ ገንዘብ", "Maallaqa seenaa"),
    "Cash out": ("የወጪ ገንዘብ", "Maallaqa ba'aa"),
    "Net cash": ("የተጣራ ገንዘብ", "Maallaqa qulqulluu"),
    "Stock movements": ("የክምችት እንቅስቃሴ", "Sochii kuusaa"),
    "No movements in this date range.": ("በዚህ የቀን ክልል ውስጥ እንቅስቃሴ የለም።", "Sochii daangaa guyyaa kana keessatti hin jiru."),
    "No sales in this date range.": ("በዚህ የቀን ክልል ውስጥ ሽያጭ የለም።", "Gurgurtaan daangaa guyyaa kana keessatti hin jiru."),
    "No rent invoices.": ("የኪራይ ደረሰኝ የለም።", "Nagaheen kiraa hin jiru."),
    "No data for this report.": ("ለዚህ ሪፖርት ውሂብ የለም።", "Gabaasa kanaaf daataan hin jiru."),
    "No payments yet.": ("እስካሁን ክፍያ የለም።", "Kaffaltiin ammatti hin jiru."),
    "Date": ("ቀን", "Guyyaa"),
    "Cashier": ("ገንዘብ ተቀባይ", "Kaashiyarii"),
    "Receipt": ("ደረሰኝ", "Nagahee"),
    "Total": ("ጠቅላላ", "Waliigala"),
    "Paid": ("የተከፈለ", "Kaffalame"),
    "Balance": ("ቀሪ", "Hafte"),
    "Due date": ("የመክፈያ ቀን", "Guyyaa kaffaltii"),
    "Payment date": ("የክፍያ ቀን", "Guyyaa kaffaltii"),
    "Item": ("ዕቃ", "Meesshaa"),
    "Name": ("ስም", "Maqaa"),
    "Type": ("ዓይነት", "Gosa"),
    "Quantity": ("መጠን", "Baay'ina"),
    "Unit": ("መለኪያ", "Safartuu"),
    "Status": ("ሁኔታ", "Haala"),
    "Tenant": ("ተከራይ", "Kireeffataa"),
    "Invoice": ("ደረሰኝ", "Nagahee"),
    "Property": ("ንብረት", "Qabeenya"),
    "Lease": ("ውል", "Waliigaltee"),
    "Rent amount": ("የኪራይ መጠን", "Hamma kiraa"),
    "Frequency": ("ድግግሞሽ", "Yeroo"),
    "Period start": ("የወቅት መጀመሪያ", "Jalqaba yeroo"),
    "Period end": ("የወቅት መጨረሻ", "Xumura yeroo"),
    "Employee": ("ሰራተኛ", "Hojjetaa"),
    "Gross pay": ("ጠቅላላ ክፍያ", "Kaffaltii waliigalaa"),
    "Net pay": ("የተጣራ ክፍያ", "Kaffaltii qulqulluu"),
    "Supplier": ("አቅራቢ", "Dhiyeessaa"),
    "Category": ("ምድብ", "Ramaddii"),
    "Payables": ("የሚከፈሉ", "Kaffaltiiwwan"),
    "Overdue receivables": ("የተላለፈ ቀነ ገደብ ዕዳ", "Liqii yeroo darbee"),
    "Stock in": ("የክምችት ገቢ", "Kuusaa seenaa"),
    "Stock out": ("የክምችት ወጪ", "Kuusaa ba'aa"),

}

TEMPLATE_SOURCES: dict[str, str] = {
    "newRecord": "New {name}",
    "editRecord": "Edit {name}",
    "deleteRecord": "Delete {name}?",
    "noRecords": "No {name} found.",
    "createRecord": "Create {name}",
    "searchRecords": "Search {name}",
    "recordDeleted": "{name} deleted.",
    "recordSaved": "{name} saved.",
    "recordExported": "{name} exported",
    "rowsExported": "{count} rows exported from Brade and Cake House",
    "savedTo": "Saved to:\n{path}\n\n{count} rows.",
    "mustBeAtLeast": "Must be at least {min}",
    "mustBeAtMost": "Must be at most {max}",
    "cakeOrderMarked": "Cake order marked {status}.",
    "markPayroll": "Mark payroll {status}?",
    "payrollMarked": "Payroll marked {status}.",
}

TEMPLATES: dict[str, tuple[str, str]] = {
    "newRecord": ("አዲስ {name}", "{name} haaraa"),
    "editRecord": ("{name} አርትዕ", "{name} gulaali"),
    "deleteRecord": ("{name} አጥፋ?", "{name} haqi?"),
    "noRecords": ("{name} የለም።", "{name} hin jiru."),
    "createRecord": ("{name} ፍጠር", "{name} uumi"),
    "searchRecords": ("{name} ፈልግ", "{name} barbaadi"),
    "recordDeleted": ("{name} ጠፍቷል።", "{name} haqame."),
    "recordSaved": ("{name} ተቀምጧል።", "{name} olkaa'ame."),
    "recordExported": ("{name} ተልኳል", "{name} al-ergame."),
    "rowsExported": (
        "{count} ረድፎች ከBrade and Cake House ተልከዋል",
        "Tarreen {count} Brade and Cake House irraa al-ergame.",
    ),
    "savedTo": (
        "የተቀመጠበት:\n{path}\n\n{count} ረድፎች።",
        "Iddoo olkaa'ame:\n{path}\n\nTarree {count}.",
    ),
    "mustBeAtLeast": ("ቢያንስ {min} መሆን አለበት", "Xiqqaatee {min} ta'uu qaba"),
    "mustBeAtMost": ("ቢበዛ {max} መሆን አለበት", "Baay'atee {max} ta'uu qaba"),
    "cakeOrderMarked": (
        "የኬክ ትዕዛዝ {status} ተደርጓል።",
        "Ajajni keekii {status} godhame.",
    ),
    "markPayroll": (
        "የደመወዝ ክፍያ {status} ምልክት አድርግ?",
        "Kaffaltii mindaa {status} godhi?",
    ),
    "payrollMarked": (
        "የደመወዝ ክፍያ {status} ተደርጓል።",
        "Kaffaltiin mindaa {status} godhame.",
    ),
}


def dart_map(values: dict[str, str]) -> str:
    lines = []
    for key, value in values.items():
        lines.append(f"    {json.dumps(key, ensure_ascii=False)}: {json.dumps(value, ensure_ascii=False)},")
    return "\n".join(lines)


def main() -> None:
    am = {key: pair[0] for key, pair in UI.items()}
    om = {key: pair[1] for key, pair in UI.items()}
    am_templates = {key: pair[0] for key, pair in TEMPLATES.items()}
    om_templates = {key: pair[1] for key, pair in TEMPLATES.items()}
    am_words = {key: pair[0] for key, pair in WORDS.items()}
    om_words = {key: pair[1] for key, pair in WORDS.items()}

    output = f"""// Generated by tool/generate_ui_text.py. Do not edit by hand.
import 'package:flutter/widgets.dart';

const Map<String, Map<String, String>> _uiTranslations = {{
  'am': {{
{dart_map(am)}
  }},
  'om': {{
{dart_map(om)}
  }},
}};

const Map<String, Map<String, String>> _wordTranslations = {{
  'am': {{
{dart_map(am_words)}
  }},
  'om': {{
{dart_map(om_words)}
  }},
}};

const Set<String> _technicalWords = {{{', '.join(json.dumps(w) for w in sorted(TECHNICAL))}}};

const Map<String, String> uiTemplateSources = {{
{chr(10).join(f"  {json.dumps(k)}: {json.dumps(v)}," for k, v in TEMPLATE_SOURCES.items())}
}};

const Map<String, Map<String, String>> _templateTranslations = {{
  'am': {{
{dart_map(am_templates)}
  }},
  'om': {{
{dart_map(om_templates)}
  }},
}};

/// Translates a known UI phrase. Unknown English is returned unchanged so
/// data values (names, product codes) are never mangled.
const List<String> uiTextKeys = [
{chr(10).join(f"  {json.dumps(k, ensure_ascii=False)}," for k in UI)}
];

const List<String> uiTemplateKeys = [
{chr(10).join(f"  {json.dumps(k, ensure_ascii=False)}," for k in TEMPLATES)}
];

/// Pure lookup used by tests and by [uiText].
String uiTextForLocale(String code, String english) {{
  if (code == 'en') return english;
  final exact = _uiTranslations[code]?[english];
  if (exact != null) return exact;
  return _translateWords(code, english);
}}

String uiText(BuildContext context, String english) {{
  return uiTextForLocale(Localizations.localeOf(context).languageCode, english);
}}

String _translateWords(String code, String english) {{
  final words = _wordTranslations[code];
  if (words == null) return english;
  final matches = RegExp(r"[A-Za-z][A-Za-z\']*").allMatches(english);
  final buffer = StringBuffer();
  var last = 0;
  for (final match in matches) {{
    buffer.write(english.substring(last, match.start));
    final word = match.group(0)!;
    final lower = word.toLowerCase();
    final translated = words[lower];
    if (translated != null) {{
      buffer.write(translated);
    }} else if (_technicalWords.contains(lower)) {{
      buffer.write(word);
    }} else {{
      buffer.write(word);
    }}
    last = match.end;
  }}
  buffer.write(english.substring(last));
  return buffer.toString();
}}

/// Translates a template such as `newRecord` and replaces `{{name}}` style
/// placeholders. The template itself is never shown to the user.
String uiTemplateForLocale(String code, String key) {{
  if (code == 'en') return uiTemplateSources[key] ?? key;
  return _templateTranslations[code]?[key] ?? key;
}}

String uiTextFormat(
  BuildContext context,
  String key,
  Map<String, String> values,
) {{
  var text = uiTemplateForLocale(Localizations.localeOf(context).languageCode, key);
  for (final entry in values.entries) {{
    text = text.replaceAll('{{${{entry.key}}}}', entry.value);
  }}
  return text;
}}

/// A [Text] widget that localizes a known UI phrase without threading a
/// context through every call site.
class LText extends StatelessWidget {{
  const LText(
    this.text, {{
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  }});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {{
    return Text(
      uiText(context, text),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }}
}}
"""
    target = ROOT / "lib" / "l10n" / "ui_text.dart"
    target.write_text(output, encoding="utf-8")
    print(f"Wrote {target} ({len(UI)} phrases, {len(TEMPLATES)} templates)")


if __name__ == "__main__":
    main()
