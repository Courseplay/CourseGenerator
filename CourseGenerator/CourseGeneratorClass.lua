
CourseGeneratorClass = CpObject()

function CourseGeneratorClass:debug(...)
    cg.debug(self.__name .. string.format(...))
end