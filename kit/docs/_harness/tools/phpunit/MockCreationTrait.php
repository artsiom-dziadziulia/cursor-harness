<?php
declare(strict_types=1);

namespace Magento\Framework\TestFramework\Unit\Helper;

use PHPUnit\Framework\MockObject\MockObject;

/**
 * Polyfill of the Magento 2.4.9 test helper for older frameworks (local harness only).
 */
trait MockCreationTrait
{
    /**
     * Create partial mock; methods missing on the class (magic getters/setters) are added
     *
     * @param string $className
     * @param array $methods
     * @return MockObject
     */
    protected function createPartialMockWithReflection(string $className, array $methods = []): MockObject
    {
        $existing = [];
        $magic = [];
        foreach ($methods as $method) {
            if (method_exists($className, $method)) {
                $existing[] = $method;
            } else {
                $magic[] = $method;
            }
        }

        $builder = $this->getMockBuilder($className)->disableOriginalConstructor();
        // PHPUnit 9.5: onlyMethods([]) sets the "empty methods" flag that discards addMethods()
        if ($existing || !$magic) {
            $builder->onlyMethods($existing);
        }
        if ($magic) {
            $builder->addMethods($magic);
        }

        return $builder->getMock();
    }
}
