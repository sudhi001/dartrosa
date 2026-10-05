# Repeats

[Catalog](README.md) › Repeats

Form: [`forms/repeats.xml`](../../packages/dartrosa_flutter/test/screenshots/forms/repeats.xml)

- [In scroll mode](#in-scroll-mode)
- [In the pager](#in-the-pager)
- [jr:count](#jrcount)
- [jr:noAddRemove](#jrnoaddremove)

## In scroll mode

<img src="../images/screenshots/widgets/repeat.png" width="360" alt="Two Household member cards with delete buttons, and Add Household member"> <img src="../images/screenshots/widgets/repeat_dark.png" width="360" alt="The same in the dark theme">

| type | name | label |
|---|---|---|
| begin_repeat | member | Household member |
| text | name | Name |
| integer | age | Age |
| end_repeat | | |

```xml
<group ref="/data/member">
  <label>Household member</label>
  <repeat nodeset="/data/member">
    <input ref="/data/member/name"><label>Name</label></input>
    <input ref="/data/member/age"><label>Age</label></input>
  </repeat>
</group>
```

Each instance is a card headed with its name and position ("Household
member 1/2"). **Add Household member** adds an instance; the delete
button asks first, because the instance's answers go with it:

<img src="../images/screenshots/widgets/repeat_remove_dialog.png" width="270" alt="Remove Household member 1/2? dialog">

## In the pager

<img src="../images/gifs/repeat_add.gif" width="270" alt="Next after the last member asks to add another; Add group, typing the new member's name and age"> <img src="../images/screenshots/widgets/repeat_prompt.png" width="270" alt="The Add a new Household member group? page">

Like Collect, after the last instance the pager asks "Add a new
"Household member" group?": **Add group** adds one and shows its first
question, **Do not add** moves past the repeat.

## jr:count

<img src="../images/screenshots/widgets/repeat_count.png" width="360" alt="The count 2, then the cards Plot 1/2 and Plot 2/2 without add or delete buttons"> <img src="../images/screenshots/widgets/repeat_count_pager.png" width="270" alt="A question of a jr:count repeat instance on a pager screen">

| type | name | label | repeat_count |
|---|---|---|---|
| integer | plots | How many plots do you farm? | |
| begin_repeat | plot | Plot | ${plots} |
| text | crop | Main crop on this plot | |
| end_repeat | | | |

```xml
<repeat nodeset="/data/plot" jr:count="/data/plots">
```

There are as many instances as the count, without add or delete
buttons, and the pager never asks to add more. The pager creates each
instance as it moves into it, as JavaRosa does; scroll mode creates them
all when the form opens and whenever the count goes up
(`XFormController.createCountedRepeatInstances`). As in JavaRosa,
instances beyond a count that went down stay.

## jr:noAddRemove

<img src="../images/screenshots/widgets/repeat_no_add_remove.png" width="360" alt="A Visit instance without add or delete buttons">

```xml
<repeat nodeset="/data/visit" jr:noAddRemove="true()">
```

The instances in the form are shown without add or delete buttons.

Theming: instance cards are `XFormCard`s ([Groups](groups.md#theming));
the delete button is an `IconButton`, the confirmation an `AlertDialog`
whose Remove button uses `XFormTheme.errorColor`. Strings:
`XFormLocalizations.addRepeat`, `addRepeatPrompt`, `addGroup`,
`doNotAdd`, `remove`, `removeRepeatTitle`, `removeRepeatMessage`.
