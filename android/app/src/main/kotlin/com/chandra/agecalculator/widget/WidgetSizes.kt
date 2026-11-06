package com.chandra.agecalculator.widget

/** Which layout the widget uses at a size, and how many events it lists. */
enum class WidgetForm {
    /** 1x1 and other very small sizes: countdown and name. */
    TINY,

    /** One cell tall: the next event in a single row. */
    STRIP,

    /** Around 2x2: the next event with a large countdown. */
    CARD,

    /** Narrow and tall: a list with the countdown under each title. */
    COLUMN,

    /** Wide: a list with dates, countdowns on the right. */
    LIST,
}

data class WidgetLayoutSpec(val form: WidgetForm, val rows: Int = 1)

/** Pure size rules, shared by the API 31+ size map and older launchers. */
object WidgetSizes {
    const val MAX_ROWS = 6

    // Header (28dp) plus top and bottom padding (10dp each).
    private const val LIST_CHROME = 48

    // One wide row: 44dp minimum plus a 3dp gap, rounded up.
    private const val LIST_ROW = 48

    // One narrow row: 40dp minimum plus a 3dp gap, rounded up.
    private const val COLUMN_ROW = 44

    fun specFor(widthDp: Int, heightDp: Int): WidgetLayoutSpec = when {
        widthDp < 110 -> WidgetLayoutSpec(WidgetForm.TINY)
        heightDp < 96 ->
            WidgetLayoutSpec(if (widthDp >= 160) WidgetForm.STRIP else WidgetForm.TINY)
        widthDp < 250 ->
            if (columnRows(heightDp) >= 3) {
                WidgetLayoutSpec(WidgetForm.COLUMN, columnRows(heightDp))
            } else {
                WidgetLayoutSpec(WidgetForm.CARD)
            }
        else -> WidgetLayoutSpec(WidgetForm.LIST, listRows(heightDp))
    }

    fun listRows(heightDp: Int): Int =
        ((heightDp - LIST_CHROME) / LIST_ROW).coerceIn(1, MAX_ROWS)

    fun columnRows(heightDp: Int): Int =
        ((heightDp - LIST_CHROME) / COLUMN_ROW).coerceIn(1, MAX_ROWS)

    /**
     * Breakpoints for the API 31+ size map, as (width, height) in dp. The
     * launcher picks the largest one that fits the widget, so each layout
     * starts exactly where [specFor] starts using it.
     */
    fun breakpoints(): List<Pair<Int, Int>> = buildList {
        add(40 to 40)
        add(160 to 40)
        add(110 to 96)
        for (rows in 3..MAX_ROWS) add(110 to LIST_CHROME + COLUMN_ROW * rows)
        for (rows in 1..MAX_ROWS) add(250 to LIST_CHROME + LIST_ROW * rows)
    }
}
