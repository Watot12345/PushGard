<?php

namespace App\Services;

/**
 * Exponential Moving Average (EMA) smoother matching mobile EmaSmoother.
 */
final class EmaSmoother
{
    private ?float $value = null;

    public function __construct(
        private readonly float $alpha,
    ) {}

    public function reset(): void
    {
        $this->value = null;
    }

    public function addSample(float $raw): float
    {
        if ($this->value === null) {
            $this->value = $raw;
        } else {
            $this->value = ($this->alpha * $raw) + ((1.0 - $this->alpha) * $this->value);
        }

        return $this->value;
    }
}
