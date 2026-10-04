/// The non-Gregorian date appearances of ODK Collect: `ethiopian`,
/// `coptic`, `islamic`, `bikram-sambat`, `myanmar`, `persian` and
/// `buddhist`.
///
/// - [DatePickerDetails.fromAppearance] tells which calendar and spinners
///   a date question uses.
/// - [CustomCalendar] converts the Gregorian dates ODK stores to the
///   calendar's dates and gives the month names and year range Collect's
///   spinners offer.
/// - [dateTimeLabel] is the text Collect shows for an answer.
/// - [CustomDatePickerModel] is the state of Collect's spinner dialog,
///   whose [CustomDatePickerModel.gregorianDate] is the date to store.
///
/// Ports of ODK Collect's date widget logic and of the calendar libraries
/// it uses (Joda-Time, persianjodatime, bikram-sambat, myanmar-calendar);
/// conversions match those libraries day for day from 1880 to 2120.
library;

export 'src/custom_calendar.dart';
export 'src/custom_date_picker.dart';
export 'src/date_picker_details.dart';
export 'src/date_time_label.dart';
