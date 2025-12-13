package com.anujsyadav.swiftspeak;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.View;

import java.util.ArrayList;
import java.util.List;

public class WaveformView extends View {

    private Paint paint;
    private List<Float> amplitudes = new ArrayList<>();
    private int maxBars = 30;
    private float barWidth = 10f;
    private float barSpacing = 5f;

    public WaveformView(Context context) {
        super(context);
        init();
    }

    public WaveformView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    private void init() {
        paint = new Paint();
        paint.setColor(Color.WHITE);
        paint.setStyle(Paint.Style.FILL);
        paint.setAntiAlias(true);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(barWidth);
    }

    public void updateAmplitude(float amplitude) {
        amplitudes.add(amplitude);
        if (amplitudes.size() > maxBars) {
            amplitudes.remove(0);
        }
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        int width = getWidth();
        int height = getHeight();
        int centerY = height / 2;

        // Calculate total width of all bars
        float totalWidth = (amplitudes.size() * barWidth) + ((amplitudes.size() - 1) * barSpacing);
        float startX = (width - totalWidth) / 2;

        for (int i = 0; i < amplitudes.size(); i++) {
            float amplitude = amplitudes.get(i);
            // Scale amplitude to height (max height is view height)
            float barHeight = amplitude * height * 0.8f;
            if (barHeight < 5)
                barHeight = 5; // Min height

            float x = startX + (i * (barWidth + barSpacing));
            float top = centerY - (barHeight / 2);
            float bottom = centerY + (barHeight / 2);

            canvas.drawLine(x, top, x, bottom, paint);
        }
    }
}
