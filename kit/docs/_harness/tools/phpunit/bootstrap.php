<?php
declare(strict_types=1);

/**
 * Harness unit-test bootstrap.
 *
 * Stack 17 runs PHP 8.4 with PHPUnit 9.5.24: PHPUnit's own sources emit E_DEPRECATED
 * ("implicitly nullable parameter"), and Magento's error handler turns every reported
 * error into an exception, so the stock bootstrap cannot even start the runner.
 * Deprecations are therefore excluded from error_reporting after the stock bootstrap ran.
 *
 * Module tests are written against the CI framework (Magento 2.4.9), which ships
 * MockCreationTrait; Magento 2.4.8-p4 in the stack does not, so a minimal polyfill is defined.
 */
require '/var/www/html/dev/tests/unit/framework/bootstrap.php';

error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

if (!trait_exists(\Magento\Framework\TestFramework\Unit\Helper\MockCreationTrait::class)) {
    require __DIR__ . '/MockCreationTrait.php';
}
